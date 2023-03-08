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
    let deviceUuid: String
    
    func copyToDevice(bundleId: String, source: String, destination: String) throws {
        // The -R flag is necessary, as it turns out to deal with symlinks that `cp -r ...` report cause a cycle
        // TODO: deal with symlinks that still point back to the previous directory
        try safeShell("cp -R \(source) \(currentHomeDir(bundleId))/\(destination)")
    }
    
    func copyFromDevice(bundleId: String, source: String, destination: String) throws {
        // In order to match ios-deploy's behavior, create all ancestor directories from src and put the src dir in there
        guard let sourceURL = NSURL(string: source) else {
            return
        }
        let dstFull = "\(destination)/\(String(describing: sourceURL.lastPathComponent))"
        
        try safeShell("mkdir -p \(dstFull)")
        try safeShell("cp -R \(currentHomeDir(bundleId))/\(source) \(dstFull)")
    }

    func currentHomeDir(_ bundleId: String) throws -> String {
        return try safeShellWithOutput("xcrun simctl get_app_container \(deviceUuid) \(bundleId) data")
    }
    
    func connect(with channel: PTChannel) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            channel.connect(to: in_port_t(PTPortNumber), IPv4Address: INADDR_LOOPBACK) { error, address in
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
