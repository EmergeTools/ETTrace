//
//  Symbolicator.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation
import ETModels

struct Address {
    let originalAddress: UInt64
    let offset: UInt64?
    let lib: LoadedLibrary?
}

typealias SymbolicationResult = [UInt64: (String, String, Bool)]

public class StackSymbolicator {
    var formatSymbolCache: [String: String] = [:]
    
    let isSimulator: Bool
    let dSymsDir: String?
    let osBuild: String
    let osVersion: String?
    let arch: String
    let verbose: Bool
    
    public init(isSimulator: Bool, dSymsDir: String?, osBuild: String, osVersion: String?, arch: String, verbose: Bool) {
        self.isSimulator = isSimulator
        self.dSymsDir = dSymsDir
        self.osBuild = osBuild
        self.osVersion = osVersion
        self.arch = arch
        self.verbose = verbose
    }

    // Return value is map of address to (lib, symbol, isMissing)
    func symbolicate(_ stacks: [Stack], _ loadedLibs: [LoadedLibrary]) -> SymbolicationResult {
        var libToAddrs: [LoadedLibrary: Set<UInt64>] = [:]
        let stacks = stacksFromResults(stacks, loadedLibs)
        stacks.flatMap { $0 }.forEach { addr in
            if let lib = addr.lib, let offset = addr.offset {
              libToAddrs[lib, default: []].insert(offset)
            }
        }
        
        let stateLock = NSLock()
        var libToCleanedPath = [String: (String, String)]()
        var libToAddrToSym: [String: [UInt64: String]] = [:]
        let queue = DispatchQueue(label: "com.emerge.symbolication", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()

        for (lib, _) in libToAddrs {
          let cleanedPath = cleanedUpPath(lib.path)
          libToCleanedPath[lib.path] = (cleanedPath, URL(string: cleanedPath)?.lastPathComponent ?? "")
        }
        let systemLibs = libToAddrs.filter { key, _ in isSystemLib(key.path) }
        let userLibs = libToAddrs.filter { key, _ in !isSystemLib(key.path) }

        group.enter()
        try? apiAddrToSymbol(systemLibs.mapKeys { $0.path }) { result in
          stateLock.lock()
          for (k, v) in result {
            libToAddrToSym[k] = v
          }
          stateLock.unlock()
          group.leave()
        }
        for (lib, addrs) in userLibs {
            group.enter()
            queue.async {
                if let dSym = self.dsymForLib(lib) {
                    let addrToSym = Self.addrToSymForBinary(dSym, addrs)
                    stateLock.lock()
                    libToAddrToSym[lib.path] = addrToSym
                    stateLock.unlock()
                }
                group.leave()
            }
        }
        group.wait()
        
        var noLibCount = 0
        var noSymMap: [String: UInt64] = [:]
        var result: SymbolicationResult = [:]
        stacks.forEach { stack in
            stack.forEach { addr in
                if let lib = addr.lib, let offset = addr.offset {
                    let (libPath, lastPathComponent) = libToCleanedPath[lib.path]!
                    guard let addrToSym = libToAddrToSym[lib.path],
                          let sym = addrToSym[offset] else {
                        noSymMap[libPath, default: 0] += 1
                      result[addr.originalAddress] = (libPath, lastPathComponent, true)
                      return
                    }
                    result[addr.originalAddress] = (libPath, formatSymbol(sym), false)
                } else {
                    noLibCount += 1
                }
            }
        }
        let totalCount = stacks.flatMap { $0 }.count
        let noLibPercentage = (Double(noLibCount) / Double(totalCount) * 100.0)
        if verbose {
            print("\(noLibPercentage)% have no library")
            for (key, value) in noSymMap {
                let percentage = (Double(value) / Double(totalCount) * 100.0)
                print("\(percentage)% from \(key) have library but no symbol")
            }
        }
        return result
    }

    private func isSystemLib(_ path: String) -> Bool {
      path.contains(".app/") && !path.contains("/Xcode.app/")
    }

    private func cleanedUpPath(_ path: String) -> String {
        if isSystemLib(path) {
            return path.split(separator: "/").drop(while: { $0.hasSuffix(".app") }).joined(separator: "/")
        } else if path.contains("/RuntimeRoot/") {
            if let index = path.range(of: "/RuntimeRoot/")?.upperBound {
                return String(path[index...])
            }
        }
        return path
    }
    
    private func stacksFromResults(_ stacks: [Stack], _ loadedLibs: [LoadedLibrary]) -> [[Address]] {
        let sortedLibs = loadedLibs.sorted(by: { $0.loadAddress > $1.loadAddress } )
        let firstTextSize: UInt64 = 50 * 1024 * 1024
        var addrToAddress: [UInt64: Address] = [:]

        let addrs: [[Address]] = stacks.map { stack in
            return stack.stack.map { addr in
                let cachedAddress = addrToAddress[addr]
                if let cachedAddress = cachedAddress {
                    return cachedAddress
                }

                var lib: LoadedLibrary? = sortedLibs.first(where: { $0.loadAddress <= addr })

                if lib == sortedLibs.first {
                    if !(addr < sortedLibs.first!.loadAddress + firstTextSize) {
                        // TODO: sometimes there are a few really large addresses that neither us nor instruments can symbolicate. Investigate why
                        lib = nil
                    }
                }

                if lib == nil {
                    if verbose {
                        print("\(addr) not contained within any frameworks")
                    }
                    return Address(originalAddress: addr, offset: nil, lib: nil)
                }

                let address = Address(originalAddress: addr, offset: addr - lib!.loadAddress, lib: lib)
                addrToAddress[addr] = address
                return address
            }
        }

        return addrs
    }

  private func apiAddrToSymbol(_ systemLibToAddrs: [String : Set<UInt64>], completion: @escaping ([String: [UInt64: String]]) -> Void) throws {
    guard let osVersion else {
      completion([:])
      return
    }

    let addressGroups = systemLibToAddrs.map { (path, addrs) in
        return ["library": path, "addresses": Array(addrs)]
    }
    let dataFile = FileManager.default.temporaryDirectory.appendingPathComponent("out.json").path
    let data: [String: Any] = ["token": "15046010248070008", "addressGroups": addressGroups, "osProductVersion": osVersion, "osBuildVersion": osBuild]

    let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
    try jsonData.write(to: URL(fileURLWithPath: dataFile))

    let endpoint = "https://api.emergetools.com/symbolication"
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.httpBody = try? Data(contentsOf: URL(fileURLWithPath: dataFile))

    URLSession.shared.dataTask(with: request) { responseData, _, _ in
      guard let responseData else {
        completion([:])
        return
      }

      let jsonObject = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
      let libraryToAddressToSymbol = jsonObject?["libraryToAddressToSymbol"] as? [String: [String: String]]
      let result = libraryToAddressToSymbol?.mapValues({ addressToSymbol in
        return addressToSymbol.mapKeys { UInt64($0)! }
      })
      completion(result ?? [:])
    }.resume()
  }

    private static func addrToSymForBinary(_ binary: String, _ addrs: Set<UInt64>) -> [UInt64: String] {
        let addrsArray = Array(addrs)
        let addrsFile = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)!.path

        let addition: UInt64 = 0x1000000 // atos can fail when the load address is 0, so add extra
        let strs = addrsArray.map { String($0 + addition, radix: 16) }
        try! strs.joined(separator: "\n").write(toFile: addrsFile, atomically: true, encoding: .utf8)

        let arch = try? safeShellWithOutput("/usr/bin/file \"\(binary)\"").contains("arm64e") ? "arm64e" : "arm64"

        try! strs.joined(separator: "\n").write(toFile: addrsFile, atomically: true, encoding: .utf8)

        let symsStr = try? safeShellWithOutput("/usr/bin/atos -l \(String(addition, radix: 16)) -arch \(arch!) -o \"\(binary)\" -f \(addrsFile)")

        let syms = symsStr!.split(separator: "\n").enumerated().map { (idx, sym) -> (UInt64, String?) in
            let trimmed = sym.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count == 0 || trimmed.starts(with: "0x") || trimmed == strs[idx] {
                return (addrsArray[idx], nil)
            } else {
                return (addrsArray[idx], trimmed)
            }
        }.filter({ (_, sym) in
            return sym != nil
        })

        var result: [UInt64: String] = [:]
        for (addr, sym) in syms {
            result[addr] = sym
        }

        return result
    }

    private func formatSymbol(_ sym: String) -> String {
        if let cachedResult = formatSymbolCache[sym] {
            return cachedResult
        }
        let result = sym.replacingOccurrences(of: ":\\d+\\)", with: ")", options: .regularExpression) // static AppDelegate.$main() (in emergeTest) (AppDelegate.swift:10)
            .replacingOccurrences(of: " \\+ \\d+$", with: "", options: .regularExpression) // _dyld_start (in dyld) + 0
            .replacingOccurrences(of: " (<compiler-generated>)$", with: "", options: .regularExpression) // static UIApplicationDelegate.main() (in emergeTest) (<compiler-generated>)
            .replacingOccurrences(of: " \\(\\S+.\\S+\\)$", with: "", options: .regularExpression) // static AppDelegate.$main() (in emergeTest) (AppDelegate.swift)
            .replacingOccurrences(of: " \\(in (\\S| )+\\)", with: "", options: .regularExpression) // static AppDelegate.$main() (in emergeTest)
            .replacingOccurrences(of: "^__\\d+\\+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^__\\d+\\-", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        formatSymbolCache[sym] = result
        return result
    }
    
    private func dsymForLib(_ lib: LoadedLibrary) -> String? {
        let libPath = lib.path
        
        if libPath.contains(".app/") {
            // Look for matching dsyms
            if let dsymsDir = dSymsDir {
                let libName = URL(fileURLWithPath: libPath).lastPathComponent
                let folderExtension = libPath.contains(".framework") ? "framework" : "app"
                let dsyms = try? FileManager.default.contentsOfDirectory(atPath: "\(dsymsDir)/\(libName).\(folderExtension).dSYM/Contents/Resources/DWARF/")
                if let dsym = dsyms?.first {
                    return "\(dsymsDir)/\(libName).\(folderExtension).dSYM/Contents/Resources/DWARF/\(dsym)"
                }
            }

            // Use spotlight to find dsyms
            let foundDsyms = try? safeShellWithOutput("/usr/bin/mdfind \"com_apple_xcode_dsym_uuids == \(lib.uuid)\"").components(separatedBy: .newlines)
            if let foundDsym = foundDsyms?.first {
                let dwarfFiles = try? FileManager.default.contentsOfDirectory(atPath: "\(foundDsym)/Contents/Resources/DWARF/")
                if let dwarfFile = dwarfFiles?.first {
                    return "\(foundDsym)/Contents/Resources/DWARF/\(dwarfFile)"
                }
            }
            // Try using the binary in the simulator to symbolicate
            if isSimulator {
              return libPath
            }
            return nil
        } else {
          if !isSimulator {
            // Get symbols from device support dir
            let searchFolder = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Developer/Xcode/iOS DeviceSupport"
            let directories = (try? FileManager.default.contentsOfDirectory(atPath: searchFolder)) ?? []
            
            for folder in directories where folder.contains(osBuild) && folder.hasSuffix(arch){
                return "\(searchFolder)/\(folder)/Symbols\(libPath)"
            }
            return nil
          } else {
            return libPath
          }
        }
    }
}

extension Dictionary {
  func mapKeys<N>(_ mapper: (Key) -> N) -> [N: Value] {
    var result = [N: Value]()
    forEach { key, value in
      result[mapper(key)] = value
    }
    return result
  }
}
