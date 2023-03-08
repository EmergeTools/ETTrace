//
//  FlameNode.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

class FlameNode {
    let name: String
    let start: Double
    var duration: Double
    var children: [FlameNode]
    let library: String?
    
    init(name: String, start: Double, duration: Double, library: String?) {
        self.name = name
        self.start = start
        self.duration = duration
        self.library = library
        self.children = []
    }
    
    func stop() -> Double {
        return start + duration
    }
    
    func add(stack: [Any], duration: Double) {
        // Add a nil element at the end, or else siblings with the same name, separated by a gap, will be merged into each other
        addHelper(stack + [nil], duration: duration)
    }
    
    static func fromSamples(_ samples: [Sample], timeNormalizer: ((Double) -> Double)? = nil) -> FlameNode {
        let root = FlameNode(name: "<root>", start: 0, duration: 0, library: nil)
        for sample in samples {
            let sampleDuration = timeNormalizer?(sample.time) ?? sample.time
            root.add(stack: sample.stack, duration: sampleDuration)
        }
        return root
    }
    
    func addHelper(_ stack: [Any], duration: Double) {
        self.duration += duration
        if stack.count == 0 {
            return
        }
        let s = stack[0]
        let lib: String?
        let name: String
        if let arr = s as? [Any] {
            lib = arr[0] as? String
            name = arr[1] as! String
        } else {
            lib = nil
            name = s as? String ?? ""
        }
        if self.children.count == 0 || (self.children.last!.name != name || self.children.last!.library != lib) {
            self.children.append(FlameNode(name: name, start: self.children.last?.stop() ?? self.start, duration: 0, library: lib))
        }
        let nextStack = Array(stack.dropFirst())
        self.children.last!.addHelper(nextStack, duration: duration)
    }
    
    func toDictionary() -> [String: Any] {
        let children = self.children.filter { $0.name != "" }.map { $0.toDictionary() }
        return [
            "name": self.name,
            "start": self.start,
            "duration": self.duration,
            "library": self.library ?? NSNull(),
            "children": children,
        ]
    }
}
