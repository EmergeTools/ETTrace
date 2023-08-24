//
//  Flamegraph.swift
//  
//
//  Created by Itay Brenner on 27/6/23.
//

import Foundation

@objc
public class Flamegraph: NSObject {
    @objc
    public let osBuild: String
    
    @objc
    public let device: String
    
    @objc
    public let isSimulator: Bool
    
    @objc
    public var events: [FlamegraphEvent]
    
    @objc
    public var libraries: [String:UInt64]
    
    @objc
    public var threadNodes: [ThreadNode]
    
    public init(osBuild: String,
                device: String,
                isSimulator: Bool,
                libraries: [String:UInt64],
                events: [FlamegraphEvent],
                threadNodes: [ThreadNode]) {
        self.osBuild = osBuild
        self.device = device
        self.isSimulator = isSimulator
        self.events = events
        self.libraries = libraries
        self.threadNodes = threadNodes
    }
}
