//
//  DeviceManager.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import CommunicationFrame
import Peertalk

protocol DeviceManager {
    var communicationChannel: CommunicationChannel { get }
    var verbose: Bool { get }

    func connect() async throws -> Void
}

extension DeviceManager {
    func sendStartRecording(_ runAtStartup: Bool, _ multiThread: Bool, _ sampleRate: UInt32) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            var startFrame = _PTStartFrame(runAtStartup: runAtStartup, sampleRate: sampleRate)
            let data = Data(bytes: &startFrame, count: MemoryLayout<_PTStartFrame>.size)

            let type = multiThread ? PTFrameTypeStartMultiThread : PTFrameTypeStart
            communicationChannel.channel.sendFrame(type: UInt32(type), tag: UInt32(PTNoFrameTag), payload: data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func sendStopRecording() async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
          communicationChannel.channel.sendFrame(type: UInt32(PTFrameTypeStop), tag: UInt32(PTNoFrameTag), payload: Data()) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
  
    private func sendRequestResults() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            communicationChannel.channel.sendFrame(type: UInt32(PTFrameTypeRequestResults), tag: UInt32(PTNoFrameTag), payload: Data()) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    if verbose {
                        print("Extracting results from device...")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func getResults() async throws -> Data {
        try await sendStopRecording()
      
        await communicationChannel.waitForReportGenerated()
      
        try await sendRequestResults()

        return await communicationChannel.waitForResultsReceived()
    }
}
