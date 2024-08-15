//
//  UnsafeRawPointer+Commands.swift
//  Tracer
//
//  Created by Itay Brenner on 15/8/24.
//

import Foundation
import MachO

extension UnsafeRawPointer {
  func numberOfCommands() -> (Int, UnsafeRawPointer)? {
    let headerPointer = load(as: mach_header_64.self)
    let headerSize: Int
    if headerPointer.magic == MH_MAGIC_64 {
      headerSize = MemoryLayout<mach_header_64>.size
    } else {
      return nil
    }

    return (Int(headerPointer.ncmds), advanced(by: headerSize))
  }
  
  func processLoadComands(_ callback: (load_command, UnsafeRawPointer) -> Bool) {
    var pointer: UnsafeRawPointer
    guard let (numberOfCommands, headers) = numberOfCommands() else { return }

    if numberOfCommands > 1000 {
      print("Too many load commands")
      return
    }

    pointer = headers
    for _ in 0..<numberOfCommands {
      let command = pointer.load(as: load_command.self)
      if !callback(command, pointer) {
        break
      }
      pointer = pointer.advanced(by: Int(command.cmdsize))
    }
  }
}
