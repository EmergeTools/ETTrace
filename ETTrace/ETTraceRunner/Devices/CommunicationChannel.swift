//
//  CommunicationChannel.swift
//  ETTraceRunner
//
//  Created by Noah Martin on 4/12/23.
//

import Foundation
import CommunicationFrame
import PeerTalk

class CommunicationChannel: NSObject {
  
  lazy var channel = PTChannel(protocol: nil, delegate: self)

  private var expectedDataLength: UInt64 = 0
  private var receivedData = Data()

  private var resultsReceived: Bool = false
  private var resultsReceivedContinution: CheckedContinuation<Data, Never>?

  private var reportGenerated: Bool = false
  private var reportedGeneratedContinuation: CheckedContinuation<Void, Never>?

  private let verbose: Bool
  private var relaunch: Bool
  
  init(verbose: Bool, relaunch: Bool) {
    self.verbose = verbose
    self.relaunch = relaunch
  }
  
  func waitForReportGenerated() async {
    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [weak self] in
        if self?.reportGenerated == true {
          continuation.resume()
        } else {
          self?.reportedGeneratedContinuation = continuation
        }
      }
    }
  }
  
  func waitForResultsReceived() async -> Data {
    return await withCheckedContinuation{ continuation in
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }

        if self.resultsReceived == true {
          continuation.resume(returning: self.receivedData)
        } else {
          self.resultsReceivedContinution = continuation
        }
      }
    }
  }
  
}

extension CommunicationChannel: PTChannelDelegate {
  @objc
  func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
    dispatchPrecondition(condition: .onQueue(.main))

      if type == PTFrameTypeReportCreated {
          reportGenerated = true
          reportedGeneratedContinuation?.resume()
          reportedGeneratedContinuation = nil
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
          resultsReceivedContinution?.resume(returning: receivedData)
          resultsReceivedContinution = nil
      }
  }

  @objc
  func channelDidEnd(_ channel: PTChannel, error: Error?) {
    dispatchPrecondition(condition: .onQueue(.main))

    guard !relaunch else {
      relaunch = false
      return
    }

    if !resultsReceived {
        print("Disconnected before results received, exiting early")
        exit(1)
    } else if verbose {
        print("Disconnected")
    }
  }
}
