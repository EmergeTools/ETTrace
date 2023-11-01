//
//  FlamegraphGenerator.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation
import ETModels

class FlamegraphGenerator {
    static func generateFlamegraphs(
      events: [Event],
      stacks: [Stack],
      syms: SymbolicationResult,
      writeFolded: Bool) -> (FlameNode, [Double])
  {
        var eventTimes = [Double](repeating: 0, count: events.count)
        let times = stacks.map { $0.time }
        var timeDiffs: [Double] = []
        let sampleInterval = 0.005
        var unattributedTime = 0.0
        let partitions = partitions(times, size: 2, step: 1)
        var eventTime: Double = 0
        var eventIndex = 0
        for (t1, t2) in partitions {
            let timeDiff: Double
            if t2 - t1 > sampleInterval * 2 {
                unattributedTime += t2 - t1 - sampleInterval * 2
                timeDiff = sampleInterval * 2
                timeDiffs.append(timeDiff)
            } else {
                timeDiff = t2 - t1
                timeDiffs.append(timeDiff)
            }
            let previousIndex = eventIndex
            while eventIndex < events.count && events[eventIndex].time < t1 {
                eventIndex += 1
            }
            for i in previousIndex..<eventIndex {
                eventTimes[i] = eventTime
            }
            eventTime += timeDiff
        }
        timeDiffs.append(sampleInterval) // Assume last stack was the usual amount of time
        var samples = zip(stacks, timeDiffs).map { (stack, timeDiff) -> Sample in
            let stackSyms: [(String?, String, UInt64?)] = stack.stack.map { address in
              guard let sym = syms[address] else {
                return ("<unknown>", "<unknown>", nil)
              }
              if sym.2 {
                return (sym.0, sym.1, address)
              }
              return (sym.0, sym.1, nil)
            }
            return Sample(time: timeDiff, stack: stackSyms)
        }
        if unattributedTime > 0 {
            let stack = (nil as String?, "<unattributed>", nil as UInt64?)
            samples.append(Sample(time: unattributedTime, stack: [stack]))
        }
        if writeFolded {
            try! samples.map { $0.description }.joined(separator: "\n").write(toFile: "output.folded", atomically: true, encoding: .utf8)
        }
        let node = FlameNode.fromSamples(samples)
        return (node, eventTimes)
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
