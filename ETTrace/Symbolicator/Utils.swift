//
//  Utils.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import AppKit

func safeShell(_ command: String) throws {
    let task = Process()
    
    task.arguments = ["--login", "-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.standardInput = nil

    try task.run()
    
    task.waitUntilExit()
}

func processWithOutput(_ executable: String, args: [String]) throws -> String {
  let task = Process()

  task.arguments = args
  task.executableURL = URL(fileURLWithPath: executable)
  task.standardInput = nil

  return try runTask(task)
}

func safeShellWithOutput(_ command: String) throws -> String {
    let task = Process()

    task.arguments = ["--login", "-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.standardInput = nil

    return try runTask(task)
}

private func runTask(_ task: Process) throws -> String {
  let pipe = Pipe()
  task.standardOutput = pipe
  let group = DispatchGroup()
  group.enter()
  var result = String()
  pipe.fileHandleForReading.readabilityHandler = { fh in
      let data = fh.availableData
      if data.isEmpty { // EOF on the pipe
          pipe.fileHandleForReading.readabilityHandler = nil
          group.leave()
      } else {
        if let newString = String(data: data, encoding: .utf8) {
          result.append(newString)
        }
      }
  }

  try task.run()
  task.waitUntilExit()
  group.wait()

  return result
}
