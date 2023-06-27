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
    public var osBuild: String?
    
    @objc
    public var device: String?
    
    public init(name: String, start: Double, duration: Double, library: String?) {
        self.name = name
        self.start = start
        self.duration = duration
        self.library = library
        self.children = []
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
        let lib: String?
        let name: String
        if let arr = s as? [Any] {
            lib = arr[0] as? String
            name = arr[1] as! String
        } else {
            lib = nil
            name = s as? String ?? ""
        }
        if currentNode.children.count == 0 || (currentNode.children.last!.name != name || currentNode.children.last!.library != lib) {
          currentNode.children.append(FlameNode(name: name, start: currentNode.children.last?.stop() ?? currentNode.start, duration: 0, library: lib))
        }
        newStack = Array(newStack.dropFirst())
        currentNode = currentNode.children.last!
      }
    }
    
    public static func fromSamples(_ samples: [Sample], timeNormalizer: ((Double) -> Double)? = nil) -> FlameNode {
        let root = FlameNode(name: "<root>", start: 0, duration: 0, library: nil)
        for sample in samples {
            let sampleDuration = timeNormalizer?(sample.time) ?? sample.time
            root.add(stack: sample.stack, duration: sampleDuration)
        }
        return root
    }
}

