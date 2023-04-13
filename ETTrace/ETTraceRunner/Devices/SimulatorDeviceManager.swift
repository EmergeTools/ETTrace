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

    var communicationChannel: CommunicationChannel

    init(verbose: Bool, relaunch: Bool) {
      communicationChannel = CommunicationChannel(verbose: verbose, relaunch: relaunch)
    }
    
    func connect() async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            communicationChannel.channel.connect(to: UInt16(PTPortNumber), IPv4Address: INADDR_LOOPBACK) { error, address in
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
