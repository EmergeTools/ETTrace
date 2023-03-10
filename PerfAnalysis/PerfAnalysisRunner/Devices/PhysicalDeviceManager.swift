//
//  PhysicalDeviceManager.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import PeerTalk
import CommunicationFrame

enum ConnectionError: Error {
    case noUsbHub
    case connectionFailed
}

class PhysicalDevicemanager: DeviceManager {
    var observer: NSObjectProtocol? = nil
    
    func copyToDevice(bundleId: String, source: String, destination: String) throws {
        try safeShell("/usr/local/bin/ios-deploy --bundle_id \(bundleId) --upload=\(source) --to=\(destination)")
    }
    
    func copyFromDevice(bundleId: String, source: String, destination: String) throws {
        try safeShell("/usr/local/bin/ios-deploy --bundle_id \(bundleId) --download=\(source) --to=\(destination)")
    }
    
    func connect(with channel: PTChannel) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            if let usbHub = PTUSBHub.shared() {
                observer = NotificationCenter.default.addObserver(forName:.deviceDidAttach, object: usbHub, queue: nil) {[weak self] notification in
                    guard let deviceID = notification.userInfo?[PTUSBHubNotificationKey.deviceID] as? NSNumber else {
                        return
                    }
                    
                    NotificationCenter.default.removeObserver(self?.observer as Any)
                    
                    channel.connect(to: PTPortNumber, over: usbHub, deviceID: deviceID) { error in
                        if error != nil {
                            print("Connection failed, make sure the app is open on your device")
                            continuation.resume(throwing: ConnectionError.connectionFailed)
                        } else {
                            print("Connected")
                            continuation.resume()
                        }
                    }
                }
            } else {
                continuation.resume(throwing: ConnectionError.noUsbHub)
            }
        }
    }
}
