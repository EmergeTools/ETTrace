//
//  Symbolicator.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

struct Address {
    let addr: UInt64
    let lib: LoadedLibrary?
}

class Symbolicator {
    var formatSymbolCache: [String: String] = [:]
    
    let isSimulator: Bool
    let dSymsDir: String?
    let osVersion: String
    let arch: String
    
    init(isSimulator: Bool, dSymsDir: String?, osVersion: String, arch: String) {
        self.isSimulator = isSimulator
        self.dSymsDir = dSymsDir
        self.osVersion = osVersion
        self.arch = arch
    }
    
    func symbolicate(_ stacks: [Stack], _ loadedLibs: [LoadedLibrary]) -> [[[String]]] {
        var libToAddrs: [LoadedLibrary: [UInt64]] = [:]
        let stacks = stacksFromResults(stacks, loadedLibs)
        stacks.flatMap { $0 }.forEach { addr in
            if let lib = addr.lib {
                libToAddrs[lib, default: []].append(addr.addr)
            }
        }
        
        let stateLock = NSLock()
        var libToAddrToSym: [String: [UInt64: String]] = [:]
        let queue = DispatchQueue(label: "com.emerge.symbolication", attributes: .concurrent)
        let group = DispatchGroup()
        for (lib, addrs) in libToAddrs {
            group.enter()
            queue.async {
                if let dSym = self.dsymForLib(lib) {
                    let addrToSym = self.addrToSymForBinary(dSym, addrs)
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
        let result: [[[String]]] = stacks.map { stack in
            stack.map { addr in
                if let lib = addr.lib {
                    let libPath = cleanedUpPath(lib.path)
                    guard let addrToSym = libToAddrToSym[lib.path],
                          let sym = addrToSym[addr.addr] else {
                        noSymMap[libPath, default: 0] += 1
                        return [libPath, URL(string: libPath)?.lastPathComponent ?? ""]
                    }
                    return [libPath, formatSymbol(sym)]
                } else {
                    noLibCount += 1
                    return ["<unknown>", "<unknown>"]
                }
            }
        }
        let totalCount = stacks.flatMap { $0 }.count
        let noLibPercentage = (Double(noLibCount) / Double(totalCount) * 100.0)
        print("\(noLibPercentage)% have no library")
        for (key, value) in noSymMap {
            let percentage = (Double(value) / Double(totalCount) * 100.0)
            print("\(percentage)% from \(key) have library but no symbol")
        }
        return result
    }
    
    private func cleanedUpPath(_ path: String) -> String {
        if path.contains(".app/") && !path.contains("/Xcode.app/") {
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
                    print("\(addr) not contained within any frameworks")
                    return Address(addr: addr, lib: nil)
                }

                let address = Address(addr: addr - lib!.loadAddress, lib: lib)
                addrToAddress[addr] = address
                return address
            }
        }

        return addrs
    }
    
    private func addrToSymForBinary(_ binary: String, _ addrs: [UInt64]) -> [UInt64: String] {
        let addrsFile = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)!.path
        
        let addition: UInt64 = 0x1000000 // atos can fail when the load address is 0, so add extra
        let strs = addrs.map { String($0 + addition, radix: 16) }
        try! strs.joined(separator: "\n").write(toFile: addrsFile, atomically: true, encoding: .utf8)
        
        let arch = try? safeShellWithOutput("/usr/bin/file \"\(binary)\"").contains("arm64e") ? "arm64e" : "arm64"
        
        try! strs.joined(separator: "\n").write(toFile: addrsFile, atomically: true, encoding: .utf8)

        let symsStr = try? safeShellWithOutput("/usr/bin/atos -l \(String(addition, radix: 16)) -arch \(arch!) -o \"\(binary)\" -f \(addrsFile)")
        
        let syms = symsStr!.split(separator: "\n").enumerated().map { (idx, sym) -> (UInt64, String?) in
            if sym.starts(with: "0x") || sym == strs[idx] {
                return (addrs[idx], nil)
            } else {
                return (addrs[idx], String(sym))
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
        
        if !isSimulator && libPath.contains(".app/") {
            if let dsymsDir = dSymsDir {
                let libName = URL(fileURLWithPath: libPath).lastPathComponent
                let folderExtension = libPath.contains(".framework") ? "framework" : "app"
                let dsyms = try? FileManager.default.contentsOfDirectory(atPath: "\(dsymsDir)/\(libName).\(folderExtension).dSYM/Contents/Resources/DWARF/")
                if let dsym = dsyms?.first {
                    return "\(dsymsDir)/\(libName).\(folderExtension).dSYM/Contents/Resources/DWARF/\(dsym)"
                }
            }
            let foundDsyms = try? safeShellWithOutput("/usr/bin/mdfind \"com_apple_xcode_dsym_uuids == \(lib.uuid)\"").components(separatedBy: .newlines)
            if let foundDsym = foundDsyms?.first {
                let dwarfFiles = try? FileManager.default.contentsOfDirectory(atPath: "\(foundDsym)/Contents/Resources/DWARF/")
                if let dwarfFile = dwarfFiles?.first {
                    return "\(foundDsym)/Contents/Resources/DWARF/\(dwarfFile)"
                }
            }
            return nil
        }
        
        if !isSimulator && !libPath.contains(".app") {
            let searchFolder = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Developer/Xcode/iOS DeviceSupport"
            let directories = (try? FileManager.default.contentsOfDirectory(atPath: searchFolder)) ?? []
            
            for folder in directories where folder.contains(osVersion) && folder.hasSuffix(arch){
                return "\(searchFolder)/\(folder)/Symbols\(libPath)"
            }
        }
        
        return libPath
    }
}
