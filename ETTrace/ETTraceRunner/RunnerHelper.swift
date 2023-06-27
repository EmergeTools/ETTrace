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

class RunnerHelper {
    let dsyms: String?
    let launch: Bool
    let useSimulator: Bool
    let verbose: Bool

    var server: HttpServer? = nil
    
    init(_ dsyms: String?, _ launch: Bool, _ simulator: Bool, _ verbose: Bool) {
        self.dsyms = dsyms
        self.launch = launch
        self.useSimulator = simulator
        self.verbose = verbose
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

        try await deviceManager.sendStartRecording(launch)

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

        let symbolicator = Symbolicator(isSimulator: isSimulator, dSymsDir: dsyms, osVersion: osVersion, arch: arch, verbose: verbose)
        let syms = symbolicator.symbolicate(responseData.stacks, responseData.libraryInfo.loadedLibraries)
        let flamegraph = FlamegraphGenerator.generateFlamegraphs(stacks: responseData.stacks, syms: syms, writeFolded: verbose)
        flamegraph.osBuild = responseData.osBuild
        flamegraph.device = responseData.device

        let outJsonData: Data = JSONWrapper.toData(flamegraph)

        let jsonString = String(data: outJsonData, encoding: .utf8)!
        try jsonString.write(toFile: "output.json", atomically: true, encoding: .utf8)
        let outputUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.json")
        
        try startLocalServer(outJsonData)
        let url = URL(string: "https://emergetools.com/flamegraph")!
        NSWorkspace.shared.open(url)

        // Wait 4 seconds for results to be accessed from server, then exit
        sleep(4)
        print("Results saved to \(outputUrl)")
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
}
