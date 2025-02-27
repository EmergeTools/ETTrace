//
//  ProcessSelector.swift
//  ETTrace
//
//  Created by Noah Martin on 2/27/25.
//

import Foundation

struct RunningProcess {
  let path: String
  let pid: Int
  let bundleID: String?
}

func trimPath(_ path: String) -> String {
    let pattern = "/([^/]+\\.app)/"
    if let range = path.range(of: pattern, options: .regularExpression) {
        return String(path[range.lowerBound...])
    }
    return path
}

func listRunningProcesses() -> [RunningProcess] {
  var results: [RunningProcess] = []
  let numberOfProcesses = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0) / Int32(MemoryLayout<pid_t>.size)
  guard numberOfProcesses > 0 else { return [] }
    
  var pids = [pid_t](repeating: 0, count: Int(numberOfProcesses))
    
  let result = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
  guard result > 0 else { return [] }
    
  for pid in pids {
    if pid == 0 { continue }
      
    var pathBuffer = [CChar](repeating: 0, count: 4 * 1024)
      
    let pathResult = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
    if pathResult > 0 {
      let path = String(cString: pathBuffer)
      if path.contains("CoreSimulator/Devices/") {
        let url = URL(fileURLWithPath: path)
        var bundleID: String? = nil
        var bundleURL = url
        while bundleURL.pathComponents.count > 1 {
          if bundleURL.pathExtension == "app" {
            break
          }
          bundleURL.deleteLastPathComponent()
        }

        if bundleURL.pathExtension == "app",
        let bundle = Bundle(url: bundleURL) {
          bundleID = bundle.bundleIdentifier
        }
        results.append(.init(path: trimPath(path), pid: Int(pid), bundleID: bundleID))
      }
    }
  }
  return results
}
