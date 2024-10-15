//
//  ThreadHelper.swift
//  Tracer
//
//  Created by Itay Brenner on 23/7/24.
//

import Foundation
import Darwin
import MachO

public struct StackFrame {
  let symbol: String
  let file: String
  let address: UInt

  var demangledSymbol: String {
    return _stdlib_demangleName(symbol)
  }
}

public struct ThreadInfo: Hashable {
  let name: String
  let number: Int
}

@objc
public class ThreadHelper: NSObject {
  public static let main_thread_t = mach_thread_self()
  static var symbolsLoaded = false
  static var symbolAddressTuples = [(UInt, String)]()
  static let kMaxFramesPerStack = 512

  @objc
  public static func printThreads() {
    NSLog("Stack trace:")
    let backtrace = callStackForAllThreads()
    
    for (thread, stackframe) in backtrace {
      NSLog("Thread \(thread.number): \(thread.name)")
      
      for (index, frame) in stackframe.enumerated() {
        NSLog("  \(index) - \(frame.demangledSymbol) [0x\(String(frame.address, radix: 16))] (\(frame.file)")
      }
    }
  }
  
  public static func callStackForAllThreads() -> [ThreadInfo: [StackFrame]] {
    var result: [ThreadInfo: [StackFrame]] = [:]
    
    var count: mach_msg_type_number_t = 0
    var threads: thread_act_array_t!

    guard task_threads(mach_task_self_, &(threads), &count) == KERN_SUCCESS else {
      return result
    }

    defer {
      let size = MemoryLayout<thread_t>.size * Int(count)
      vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(size))
    }

    var frameCount: UInt64 = 0
    var frames = [UInt64](repeating: 0, count: kMaxFramesPerStack)
    for i in 0..<count {
      let index = Int(i)
      if let p_thread = pthread_from_mach_thread_np((threads[index])) {
        let thread: thread_t = threads[index]
        let pthread = pthread_from_mach_thread_np(thread)!
        if pthread == pthread_self() {
          // Skip our thread
          continue
        }
        
        let threadName = getThreadName(p_thread) ?? ""
        
        thread_suspend(thread)
        // Ensure any code here does not take locks using @_noLocks
        getStacktrace(forThread: thread, frames: &frames, maxFrames: UInt64(kMaxFramesPerStack), frameCount: &frameCount)
        thread_resume(thread)
        let stacktrace = Array(frames.prefix(Int(frameCount)))
        let stacks = getCallStack(stacktrace) ?? []

        let threadInfo: ThreadInfo = ThreadInfo(name: threadName,number: index)
        
        result[threadInfo] = stacks
      }
    }
        
    return result
  }
  
  static func getCallStack(_ array: [UInt64]) -> [StackFrame]? {
    var symbols = [StackFrame]()
    for address in array {
      var info = Dl_info()
      if dladdr(UnsafeRawPointer(bitPattern: UInt(address)), &info) != 0 {
        let functionName = info.dli_sname.map { String(cString: $0) } ?? alternativeSymbolName(UInt(address))
        let fileName = info.dli_fname.map { String(cString: $0) } ?? "<unknown>"
          
        symbols.append(StackFrame(symbol: functionName, file: fileName, address: UInt(address)))
      }
    }
    return symbols
  }
  
  static func alternativeSymbolName(_ address: UInt) -> String {
    NSLog("Using alternate name")
    if (!symbolsLoaded) {
      parseImages()
    }
    
    var previous: (UInt, String)? = nil
    for (addr, str) in symbolAddressTuples {
      if addr > address {
        return previous?.1 ?? "Invalid"
      }
      previous = (addr, str)
    }
    return "<unknown>"
  }

  private static func getThreadName(_ thread: pthread_t) -> String? {
    var name = [Int8](repeating: 0, count: 256)

    let result = pthread_getname_np(thread, &name, name.count)
    if result != 0 {
      print("Failed to get thread name: \(result)")
      return nil
    }

    return String(cString: name)
  }
  
  private static func parseImages() {
    for i in 0..<_dyld_image_count() {
      guard let header = _dyld_get_image_header(i) else { continue }
      let slide = _dyld_get_image_vmaddr_slide(i)
      
      let bytes: UnsafeRawPointer = UnsafeRawPointer(OpaquePointer(header))
      var symtabCommand: symtab_command?
      var linkeditCmd: segment_command_64?
      bytes.processLoadComands { command, commandPointer in
        switch command.cmd {
        case UInt32(LC_SYMTAB):
          let commandType = commandPointer.load(as: symtab_command.self)
          symtabCommand = commandType
        case UInt32(LC_SEGMENT_64):
          let cmd = commandPointer.load(as: segment_command_64.self)
          var segname = cmd.segname
          if strcmp(&segname, SEG_LINKEDIT) == 0 {
            linkeditCmd = commandPointer.load(as: segment_command_64.self)
          }
        default:
          break
        }
        return true
      }
      
      guard let command = symtabCommand, let linkeditCmd = linkeditCmd else { continue }
      
      let linkeditBase = slide + Int(linkeditCmd.vmaddr) - Int(linkeditCmd.fileoff)
      parseTable(command: command, linkeditBase, slide)
    }
    
    symbolAddressTuples.sort { addr1, addr2 in
      return addr1.0 < addr2.0
    }
    symbolsLoaded = true
  }

  private static func parseTable(command: symtab_command, _ linkeditBase: Int, _ slide: Int) {
    let imageBase = UnsafeRawPointer(bitPattern: linkeditBase)!
    let nsyms = command.nsyms
    let symStart = imageBase.advanced(by: Int(command.symoff))
    let strStart = imageBase.advanced(by: Int(command.stroff))
    for i in 0..<nsyms {
      let symbolStart = symStart.advanced(by: Int(i) * MemoryLayout<nlist_64>.size)
      let nlist = symbolStart.load(as: nlist_64.self)
      guard (nlist.n_type & UInt8(N_STAB) == 0) && nlist.n_value != 0 else { continue }

      let stringStart = strStart.advanced(by: Int(nlist.n_un.n_strx))
      let string = String(cString: stringStart.assumingMemoryBound(to: UInt8.self))
      
      // Add slide since frame addresses will have it
      symbolAddressTuples.append((UInt(nlist.n_value) + UInt(slide), string))
    }
  }
  
  @_noLocks static func getStacktrace(
  forThread thread: thread_t,
  frames: UnsafeMutablePointer<UInt64>,
  maxFrames: UInt64,
  frameCount: inout UInt64) {
    FIRCLSWriteThreadStack(thread, frames, maxFrames, &frameCount)
  }
}

@_silgen_name("swift_demangle")
public
func _stdlib_demangleImpl(
  mangledName: UnsafePointer<CChar>?,
  mangledNameLength: UInt,
  outputBuffer: UnsafeMutablePointer<CChar>?,
  outputBufferSize: UnsafeMutablePointer<UInt>?,
  flags: UInt32
  ) -> UnsafeMutablePointer<CChar>?

public func _stdlib_demangleName(_ mangledName: String) -> String {
  return mangledName.utf8CString.withUnsafeBufferPointer { (mangledNameUTF8CStr) in
    let demangledNamePtr = _stdlib_demangleImpl(
      mangledName: mangledNameUTF8CStr.baseAddress,
      mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
      outputBuffer: nil,
      outputBufferSize: nil,
      flags: 0)

    if let demangledNamePtr = demangledNamePtr {
      let demangledName = String(cString: demangledNamePtr)
      free(demangledNamePtr)
      return demangledName
    }
    return mangledName
  }
}

@_silgen_name("FIRCLSWriteThreadStack")
@_noLocks func FIRCLSWriteThreadStack(_ thread: thread_t, _ frames: UnsafeMutablePointer<UInt64>, _ framesCapacity: UInt64, _ framesWritten: UnsafeMutablePointer<UInt64>)
