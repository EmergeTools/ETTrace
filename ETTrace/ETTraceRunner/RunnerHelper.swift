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
import Dispatch

typealias FlamegraphTuple = (String, Thread, Flamegraph)

class RunnerHelper {
    let dsyms: String?
    let launch: Bool
    let useSimulator: Bool
    let verbose: Bool
    let multiThread: Bool

    var server: HttpServer? = nil
    var symbolicator: Symbolicator!
    
    init(_ dsyms: String?, _ launch: Bool, _ simulator: Bool, _ verbose: Bool, _ multiThread: Bool) {
        self.dsyms = dsyms
        self.launch = launch
        self.useSimulator = simulator
        self.verbose = verbose
        self.multiThread = multiThread
    }
    
    func start() async throws {
        print("Please open the app on the \(useSimulator ? "simulator" : "device")")
        if !useSimulator {
            print("Re-run with `--simulator` to connect to the simulator.")
        }
        print("Press return when ready...")
        _ = readLine()

        print("Connecting to device.")

        let deviceManager: DeviceManager = useSimulator ? SimulatorDeviceManager(verbose: verbose, relaunch: launch) : PhysicalDevicemanager(verbose: verbose, relaunch: launch)

        try await deviceManager.connect()

       try await deviceManager.sendStartRecording(launch, multiThread)

        if launch {
            print("Re-launch the app to start recording, then press return to exit")
        } else {
            print("Started recording, press return to exit")
        }

        _ = readLine()
        print("            \r")
      
        if launch {
            try await deviceManager.connect()
        }

        print("Waiting for report to be generated...");

        let receivedData = try await deviceManager.getResults()

        let localFolder = Bundle.main.bundlePath
        let outFolder = "\(localFolder)/tmp/emerge-perf-analysis/Documents/emerge-output/"
        try FileManager.default.createDirectory(atPath: outFolder, withIntermediateDirectories: true)
        let outputPath = "\(outFolder)/output.json"
        if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(atPath: outputPath)
        }
        FileManager.default.createFile(atPath: outputPath, contents: receivedData)
        
        print("Stopped recording, symbolicating...")

        let responseData = try JSONDecoder().decode(ResponseModel.self, from: receivedData)

        let isSimulator = responseData.isSimulator
        var arch = responseData.cpuType.lowercased()
        if arch == "arm64e" {
            arch = " arm64e"
        } else {
            arch = ""
        }
        var osVersion = responseData.osBuild
        osVersion.removeAll(where: { !$0.isLetter && !$0.isNumber })
        
        symbolicator = Symbolicator(isSimulator: isSimulator, dSymsDir: dsyms, osVersion: osVersion, arch: arch, verbose: verbose)
        let outputUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        let flamegraphs = await withTaskGroup(of: FlamegraphTuple.self, returning: [FlamegraphTuple].self) { taskGroup in
            for (threadId, thread) in responseData.threads {
                taskGroup.addTask {
                    (threadId, thread, await self.createFlamegraphForThread(thread, responseData))
                }
            }
            
            var tuples = [FlamegraphTuple]()
            for await result in taskGroup {
                tuples.append(result)
            }
            return tuples
        }
        
        var mainThreadFlamegraph: Flamegraph!
        var mainThreadData: Data!
        
        for (threadId, thread, flamegraph) in flamegraphs {
            let outJsonData = JSONWrapper.toData(flamegraph)!
            if thread.name == "Main Thread" {
                mainThreadFlamegraph = flamegraph
                mainThreadData = outJsonData
            }
            try saveFlamegraph(outJsonData, outputUrl, threadId)
        }
        
        guard mainThreadFlamegraph != nil else {
            fatalError("No main thread flamegraphs generated")
        }
        
        // Serve Main Thread
        try startLocalServer(mainThreadData)
        
        let url = URL(string: "https://emergetools.com/flamegraph")!
        NSWorkspace.shared.open(url)

        // Wait 4 seconds for results to be accessed from server, then exit
        sleep(4)
        print("Results saved to \(outputUrl)")
    }
    
    private func createFlamegraphForThread(_ thread: Thread, _ responseData: ResponseModel) async -> Flamegraph {
        let stacks = thread.stacks
        let syms = await symbolicator.symbolicate(stacks, responseData.libraryInfo.loadedLibraries)
        let flamegraphNodes = FlamegraphGenerator.generateFlamegraphs(stacks: stacks, syms: syms, writeFolded: verbose)
        let threadNode = ThreadNode(nodes: flamegraphNodes, threadName: thread.name)
        
        let startTime = stacks.sorted { s1, s2 in
            s1.time < s2.time
        }.first!.time
        
        let events = responseData.events.map { event in
            return FlamegraphEvent(name: event.span,
                                   type: event.type.rawValue,
                                   time: event.time-startTime)
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
