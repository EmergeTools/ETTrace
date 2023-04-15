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
  
    var communicationChannel: CommunicationChannel

    init(verbose: Bool, relaunch: Bool) {
      communicationChannel = CommunicationChannel(verbose: verbose, relaunch: relaunch)
      self.verbose = verbose
    }

    let verbose: Bool
    private var observer: NSObjectProtocol? = nil
    private var deviceID: NSNumber? = nil
  
  private func connect(withId deviceID: NSNumber, usbHub: PTUSBHub, continuation: CheckedContinuation<Void, Error>) {
      communicationChannel.channel.connect(to: PTPortNumber, over: usbHub, deviceID: deviceID) { error in
          if error != nil {
              print("Connection failed, make sure the app is open on your device")
              continuation.resume(throwing: ConnectionError.connectionFailed)
          } else {
              print("Connected")
              continuation.resume()
          }
      }
    }

    func connect() async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            if let usbHub = PTUSBHub.shared() {
              if let deviceID = self.deviceID {
                connect(withId: deviceID, usbHub: usbHub, continuation: continuation)
              } else {
                observer = NotificationCenter.default.addObserver(forName:.deviceDidAttach, object: usbHub, queue: nil) {[weak self] notification in
                    if self?.verbose == true {
                      print("Device did attach notification")
                    }
                    guard let deviceID = notification.userInfo?[PTUSBHubNotificationKey.deviceID] as? NSNumber else {
                        return
                    }
                    self?.deviceID = deviceID
                    
                    NotificationCenter.default.removeObserver(self?.observer as Any, name: .deviceDidAttach, object: usbHub)
                  
                    self?.connect(withId: deviceID, usbHub: usbHub, continuation: continuation)
                }
              }
            } else {
                continuation.resume(throwing: ConnectionError.noUsbHub)
            }
        }
    }
}
