//
//  RunnerHelper.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 8/3/23.
//

import AppKit
import Foundation
import Peertalk
import CommunicationFrame
import Swifter
import JSONWrapper
import ETModels
import Symbolicator

class RunnerHelper {
    let dsyms: String?
    let launch: Bool
    let useSimulator: Bool
    let verbose: Bool
    let saveIntermediate: Bool
    let outputDirectory: String?
    let multiThread: Bool
    let sampleRate: UInt32

    var server: HttpServer? = nil

    init(_ dsyms: String?, _ launch: Bool, _ simulator: Bool, _ verbose: Bool, _ saveIntermediate: Bool, _ outputDirectory: String?, _ multiThread: Bool, _ sampleRate: UInt32) {
        self.dsyms = dsyms
        self.launch = launch
        self.useSimulator = simulator
        self.verbose = verbose
        self.saveIntermediate = saveIntermediate
        self.outputDirectory = outputDirectory
        self.multiThread = multiThread
        self.sampleRate = sampleRate
    }

    private func printMessageAndWait() {
      print("Please open the app on the \(useSimulator ? "simulator" : "device")")
      if !useSimulator {
          print("Re-run with `--simulator` to connect to the simulator.")
      }
      print("Press return when ready...")
      _ = readLine()
    }
    
    func start() async throws {
        while useSimulator && !isPortInUse(port: Int(PTPortNumber)) {
          let running = listRunningProcesses()
          if !running.isEmpty {
            print(running.count == 1 ? "1 app was found but it is not running" : "\(running.count) apps were found but they are not running")
            for p in running {
              if let bundleId = p.bundleID {
                print("\tBundle Id: \(bundleId) path: \(p.path)")
              } else {
                print("\tPath: \(p.path)")
              }
            }
          } else {
            print("No apps found running on the simulator")
          }

          printMessageAndWait()
        }

        if !useSimulator {
          printMessageAndWait()
        }

        if verbose {
          print("Connecting to device.")
        }

        let deviceManager: DeviceManager = useSimulator ? SimulatorDeviceManager(verbose: verbose, relaunch: launch) : PhysicalDevicemanager(verbose: verbose, relaunch: launch)

        try await deviceManager.connect()

        try await deviceManager.sendStartRecording(launch, multiThread, sampleRate)

        if launch {
            print("Re-launch the app to start recording, then press return to exit")
        } else {
            print("Started recording, press return to exit")
        }

        _ = readLine()
      
        if launch {
            try await deviceManager.connect()
        }

        if verbose {
          print("Waiting for report to be generated...");
        }

        let receivedData = try await deviceManager.getResults()

        if saveIntermediate {
          let outFolder = "\(NSTemporaryDirectory())/emerge-output"
          try FileManager.default.createDirectory(atPath: outFolder, withIntermediateDirectories: true)
          let outputPath = "\(outFolder)/output.json"
          if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(atPath: outputPath)
          }
          FileManager.default.createFile(atPath: outputPath, contents: receivedData)
          print("Intermediate file saved to \(outputPath)")
        }
        
        if verbose {
          print("Stopped recording, symbolicating...")
        }

        let responseData = try JSONDecoder().decode(ResponseModel.self, from: receivedData)

        let isSimulator = responseData.isSimulator
        var arch = responseData.cpuType.lowercased()
        if arch == "arm64e" {
            arch = " arm64e"
        } else {
            arch = ""
        }
        var osBuild = responseData.osBuild
        osBuild.removeAll(where: { !$0.isLetter && !$0.isNumber })

        let threadIds = responseData.threads.keys
        let threads = threadIds.map { responseData.threads[$0]!.stacks }
        let symbolicator = StackSymbolicator(isSimulator: isSimulator, dSymsDir: dsyms, osBuild: osBuild, osVersion: responseData.osVersion, arch: arch, verbose: verbose)
        let flamegraphs = FlamegraphGenerator.generate(
          events: responseData.events,
          threads: threads,
          sampleRate: responseData.sampleRate,
          loadedLibraries: responseData.libraryInfo.loadedLibraries,
          symbolicator: symbolicator)
        let outputUrl = URL(fileURLWithPath: outputDirectory ?? FileManager.default.currentDirectoryPath)

        var mainThreadData: Data?
        for (threadId, symbolicationResult) in zip(threadIds, flamegraphs) {
            let thread = responseData.threads[threadId]!
            let flamegraph = createFlamegraphForThread(symbolicationResult.0, symbolicationResult.1, thread, responseData)
            
            let outJsonData = JSONWrapper.toData(flamegraph)!
            
            if thread.name == "Main Thread" {
                if verbose {
                    try symbolicationResult.2.write(toFile: "output.folded", atomically: true, encoding: .utf8)
                }
                mainThreadData = outJsonData
            }
            try saveFlamegraph(outJsonData, outputUrl, threadId)
        }
        
        guard let mainThreadData else {
            fatalError("No main thread flamegraphs generated")
        }
        
        // Serve Main Thread
        try startLocalServer(mainThreadData)
        
        let url = URL(string: "https://emergetools.com/ettrace")!
        NSWorkspace.shared.open(url)

        // Wait 4 seconds for results to be accessed from server, then exit
        sleep(4)
        print("Results saved to \(outputUrl)")
    }
    
  private func createFlamegraphForThread(_ flamegraphNodes: FlameNode, _ eventTimes: [Double], _ thread: Thread, _ responseData: ResponseModel) -> Flamegraph {
        let threadNode = ThreadNode(nodes: flamegraphNodes, threadName: thread.name)
        
        let events = zip(responseData.events, eventTimes).map { (event, t) in
            return FlamegraphEvent(name: event.span,
                                   type: event.type.rawValue,
                                   time: t)
        }

        let libraries = responseData.libraryInfo.loadedLibraries.reduce(into: [String:UInt64]()) { partialResult, library in
            partialResult[library.path] = library.loadAddress
        }
        
        return Flamegraph(osBuild: responseData.osBuild,
                          device: responseData.device,
                          isSimulator: responseData.isSimulator,
                          libraries: libraries,
                          events: events,
                          threadNodes: [threadNode])
    }
    
    func startLocalServer(_ data: Data) throws {
        server = HttpServer()
        
        let headers = [
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Headers": "baggage,sentry-trace"
        ]
        
        server?["/output.json"] = { a in
            if a.method == "OPTIONS" {
                return .raw(204, "No Content", [
                    "Access-Control-Allow-Methods": "GET",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "baggage,sentry-trace"
                ], nil)
            }
            
            return .raw(200, "OK", headers, { writter in
                try? writter.write(data)
                exit(0)
            })
        }
        try server?.start(37577)
    }

    private func saveFlamegraph(_ outJsonData: Data, _ outputUrl: URL, _ threadId: String? = nil) throws {
        var saveUrl = outputUrl.appendingPathComponent("output.json")
        if let threadId = threadId {
            saveUrl = outputUrl.appendingPathComponent("output_\(threadId).json")
        }
        
        let jsonString = String(data: outJsonData, encoding: .utf8)!
        try jsonString.write(to: saveUrl, atomically: true, encoding: .utf8)
    }
}
