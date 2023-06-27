//
//  FlameNode.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

@objc
public class FlameNode: NSObject {
    @objc
    public let name: String
    
    @objc
    public let start: Double
    
    @objc
    public var duration: Double
    
    @objc
    public var children: [FlameNode]
    
    @objc
    public let library: String?
    
    @objc
    public let address: NSNumber?
    
    public init(name: String, start: Double, duration: Double, library: String?, address: NSNumber?) {
        self.name = name
        self.start = start
        self.duration = duration
        self.library = library
        self.children = []
        self.address = address
    }
    
    private func stop() -> Double {
        return start + duration
    }
    
    public func add(stack: [Any], duration: Double) {
        // Add a nil element at the end, or else siblings with the same name, separated by a gap, will be merged into each other
      var newStack: [Any?] = stack + [nil]
      var currentNode = self
      while !newStack.isEmpty {
        currentNode.duration += duration
        let s = newStack[0]
        var lib: String? = nil
        let name: String
        var address: NSNumber? = nil
        if let tuple = s as? (String?, String, UInt64?) {
            lib = tuple.0
            name = tuple.1
            address = tuple.2 != nil ? NSNumber(value: tuple.2!) : nil
        } else {
            name = s as? String ?? ""
        }
        if currentNode.children.count == 0 || (currentNode.children.last!.name != name || currentNode.children.last!.library != lib) {
            let child = FlameNode(name: name,
                                  start: currentNode.children.last?.stop() ?? currentNode.start,
                                  duration: 0,
                                  library: lib,
                                  address: address)
            currentNode.children.append(child)
        }
        newStack = Array(newStack.dropFirst())
        currentNode = currentNode.children.last!
      }
    }
    
    public static func fromSamples(_ samples: [Sample], timeNormalizer: ((Double) -> Double)? = nil) -> FlameNode {
        let root = FlameNode(name: "<root>", start: 0, duration: 0, library: nil, address: nil)
        for sample in samples {
            let sampleDuration = timeNormalizer?(sample.time) ?? sample.time
            root.add(stack: sample.stack, duration: sampleDuration)
        }
        return root
    }
}

