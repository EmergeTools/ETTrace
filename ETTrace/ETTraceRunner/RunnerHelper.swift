//
//  RunnerHelper.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 8/3/23.
//

import Foundation
import PeerTalk
import CommunicationFrame
import Swifter

class RunnerHelper: NSObject, PTChannelDelegate {
    let dsyms: String?
    let launch: Bool
    let useSimulator: Bool
    
    // MARK: Peertalk
    lazy var channel = PTChannel(protocol: nil, delegate: self)
    var server: HttpServer? = nil
    var reportGenerated: Bool = false
    
    // MARK: Results
    var expectedDataLength: UInt64 = 0
    var receivedData: Data = Data()
    var resultsReceived: Bool = false
    
    init(_ dsyms: String?, _ launch: Bool, _ useSimulator: Bool) {
        self.dsyms = dsyms
        self.launch = launch
        self.useSimulator = useSimulator
    }
    
    func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
        if type == PTFrameTypeReportCreated {
            reportGenerated = true
        } else if type == PTFrameTypeResultsMetadata,
                  let payload = payload {
            let metadata = payload.withUnsafeBytes { buffer in
                buffer.load(as: PTMetadataFrame.self)
            }
            expectedDataLength = UInt64(metadata.fileSize)
            
        } else if type == PTFrameTypeResultsData,
                  let payload = payload {
            receivedData.append(payload)
        } else if type == PTFrameTypeResultsTransferComplete {
            guard receivedData.count == expectedDataLength else {
                fatalError("Received \(receivedData.count) bytes, expected \(expectedDataLength)")
            }
            resultsReceived = true
        }
    }
    
    func channelDidEnd(_ channel: PTChannel, error: Error?) {
        print("Device disconnected")
        exit(1)
    }
    
    func start() async throws {
        print("Please open the app on the \(useSimulator ? "simulator" : "device")")
        if !useSimulator {
            print("Re-run with `--use-simulator` to connect to the simulator.")
        }
        print("Press any key when ready...")
        _ = readLine()

        print("Connecting to device.")

        let deviceManager: DeviceManager = useSimulator ? SimulatorDeviceManager() : PhysicalDevicemanager()

        try await deviceManager.connect(with: channel)

        try await deviceManager.sendStartRecording(launch, channel)

        if launch {
            print("Re-launch the app to start recording, then press any key to exit")
        } else {
            print("Started recording, press any key to exit")
        }

        _ = readLine()
        print("            \r")

        try await deviceManager.sendStopRecording(channel)

        print("Waiting for report to be generated...");
        while(!reportGenerated) {
            usleep(10)
        }
        
        print("Extracting results from device...")
        try await deviceManager.requestResults(with: channel)
        while(!resultsReceived) {
            usleep(10)
        }
        
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
        
        let symbolicator = Symbolicator(isSimulator: isSimulator, dSymsDir: dsyms, osVersion: osVersion, arch: arch)
        let syms = symbolicator.symbolicate(responseData.stacks, responseData.libraryInfo.loadedLibraries)
        let flamegraph = FlamegraphGenerator.generateFlamegraphs(stacks: responseData.stacks, syms: syms) as NSDictionary
        
        let outJsonData = try JSONSerialization.data(withJSONObject: flamegraph, options: .withoutEscapingSlashes)
        let jsonString = String(data: outJsonData, encoding: .utf8)!
        try jsonString.write(toFile: "output.json", atomically: true, encoding: .utf8)
        
        try startLocalServer(outJsonData)
        let url = URL(string: "https://emergetools.com/flamegraph")!
        NSWorkspace.shared.open(url)
        
        _ = readLine()
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
