//
//  DeviceManager.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import CommunicationFrame
import PeerTalk

protocol DeviceManager {
    func copyToDevice(bundleId: String, source: String, destination: String) throws
    func copyFromDevice(bundleId: String, source: String, destination: String) throws
    func connect(with channel: PTChannel) async throws -> Void
}

extension DeviceManager {
    func sendStartRecording(_ runAtStartup: Bool, _ channel: PTChannel) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            var boolValue = runAtStartup ? 1 : 0
            let data = Data(bytes: &boolValue, count: 2)
            
            channel.sendFrame(type: UInt32(PTFrameTypeStart), tag: UInt32(PTNoFrameTag), payload: data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func sendStopRecording(_ channel: PTChannel) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            channel.sendFrame(type: UInt32(PTFrameTypeStop), tag: UInt32(PTNoFrameTag), payload: Data()) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
