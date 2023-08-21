//
//  ThreadNode.swift
//  
//
//  Created by Itay Brenner on 18/8/23.
//

import Foundation

@objc
public class ThreadNode: NSObject {
    @objc
    public let threadName: String?
    
    @objc
    public var nodes: FlameNode
    
    public init(nodes: FlameNode,
                threadName: String? = nil) {
        self.nodes = nodes
        self.threadName = threadName
    }
}
