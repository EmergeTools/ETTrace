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
    
    public init(osBuild: String, device: String?, isSimulator: Bool, nodes: FlameNode) {
        self.osBuild = osBuild
        self.device = device
        self.isSimulator = isSimulator
        self.nodes = nodes
    }
}
