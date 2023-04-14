//
//  SimulatorDeviceManager.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import PeerTalk
import CommunicationFrame

struct SimulatorDeviceManager: DeviceManager {
    var isMemory: Bool = false
    
    func connect(with channel: PTChannel) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            channel.connect(to: UInt16(PTPortNumber), IPv4Address: INADDR_LOOPBACK) { error, address in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    print("Connected")
                    continuation.resume()
                }
            }
        }
    }
}
