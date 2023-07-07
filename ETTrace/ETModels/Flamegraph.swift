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
    public let device: String?
    
    @objc
    public let isSimulator: Bool
    
    @objc
    public var nodes: FlameNode
    
    @objc
    public var events: [FlamegraphEvent]
    
    @objc
    public var libraries: [String:UInt64]
    
    public init(osBuild: String,
                device: String?,
                isSimulator: Bool,
                nodes: FlameNode,
                libraries: [String:UInt64],
                events: [FlamegraphEvent]) {
        self.osBuild = osBuild
        self.device = device
        self.isSimulator = isSimulator
        self.nodes = nodes
        self.events = events
        self.libraries = libraries
    }
}
