//
//  FlamegraphGenerator.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

class FlamegraphGenerator {
    static func generateFlamegraphs(stacks: [Stack], syms: [[Any]], isMemory: Bool) -> [String: Any] {
        if !isMemory {
            let times = stacks.map { $0.time }
            var timeDiffs: [Double] = []
            let sampleInterval = 0.005
            var unattributedTime = 0.0
            let partitions = partitions(times, size: 2, step: 1)
            for (t1, t2) in partitions {
                if t2 - t1 > sampleInterval * 2 {
                    unattributedTime += t2 - t1 - sampleInterval * 2
                    timeDiffs.append(sampleInterval * 2)
                } else {
                    timeDiffs.append(t2 - t1)
                }
            }
            timeDiffs.append(sampleInterval) // Assume last stack was the usual amount of time
        
            var samples = zip(syms, timeDiffs).map { (stackSyms, timeDiff) -> Sample in
                return Sample(time: timeDiff, stack: stackSyms)
            }
            if unattributedTime > 0 {
                samples.append(Sample(time: unattributedTime, stack: [[nil, "<unattributed>"]]))
            }
            try! samples.map { $0.description }.joined(separator: "\n").write(toFile: "output.folded", atomically: true, encoding: .utf8)
            let node = FlameNode.fromSamples(samples)
            return node.toDictionary()
        } else {
            let memory = stacks.map { $0.allocatedMemory ?? 0 }
            let samples = zip(syms, memory).map { (stackSyms, mem) -> MemorySample in
                return MemorySample(memory: mem, stack: stackSyms)
            }
            try! samples.map { $0.description }.joined(separator: "\n").write(toFile: "output_memory.folded", atomically: true, encoding: .utf8)
            
            return ["A": 1]
        }
    }
    
    private static func partitions(_ array: [Double], size: Int, step: Int? = nil) -> [(Double, Double)] {
        let step = step ?? size
        var startIdx = 0
        var endIdx = size - 1
        var partitions: [(Double, Double)] = []
        while Int(endIdx) < array.count {
            partitions.append( (array[startIdx], array[endIdx]) )
            startIdx += step
            endIdx += step
        }
        return partitions
    }
}
