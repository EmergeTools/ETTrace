//
//  FlamegraphGenerator.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation
import ETModels
import JSONWrapper

public enum FlamegraphGenerator {

  public static func generate(
    data: Data,
    dSymsDir: String?,
    verbose: Bool) throws -> [(name: String, threadId: String, flamegraph: Data)]
  {
    let responseData = try JSONDecoder().decode(ResponseModel.self, from: data)
    let isSimulator = responseData.isSimulator
    var arch = responseData.cpuType.lowercased()
    if arch == "arm64e" {
        arch = " arm64e"
    } else {
        arch = ""
    }
    var osBuild = responseData.osBuild
    osBuild.removeAll(where: { !$0.isLetter && !$0.isNumber })

    let threadIds = responseData.threads.keys
    let threads = threadIds.map { responseData.threads[$0]!.stacks }
    let symbolicator = StackSymbolicator(isSimulator: isSimulator, dSymsDir: dSymsDir, osBuild: osBuild, osVersion: responseData.osVersion, arch: arch, verbose: verbose)

    let syms = symbolicator.symbolicate(threads.flatMap { $0 }, responseData.libraryInfo.loadedLibraries)
    let flamegraphs = threads.map { generateFlameNode(events: responseData.events, stacks: $0, syms: syms) }
    var result = [(String, String, Data)]()
    for (threadId, symbolicationResult) in zip(threadIds, flamegraphs) {
      let thread = responseData.threads[threadId]!
      let flamegraph = createFlamegraphForThread(symbolicationResult.0, symbolicationResult.1, thread, responseData)
      if verbose && thread.name == "Main Thread" {
          try symbolicationResult.2.write(toFile: "output.folded", atomically: true, encoding: .utf8)
      }

      let outJsonData = JSONWrapper.toData(flamegraph)!
      result.append((thread.name, threadId, outJsonData))
    }
    return result
  }

  private static func createFlamegraphForThread(_ flamegraphNodes: FlameNode, _ eventTimes: [Double], _ thread: Thread, _ responseData: ResponseModel) -> Flamegraph {
         let threadNode = ThreadNode(nodes: flamegraphNodes, threadName: thread.name)

         let events = zip(responseData.events, eventTimes).map { (event, t) in
             return FlamegraphEvent(name: event.span,
                                    type: event.type.rawValue,
                                    time: t)
         }

         let libraries = responseData.libraryInfo.loadedLibraries.reduce(into: [String:UInt64]()) { partialResult, library in
             partialResult[library.path] = library.loadAddress
         }

         return Flamegraph(osBuild: responseData.osBuild,
                           device: responseData.device,
                           isSimulator: responseData.isSimulator,
                           libraries: libraries,
                           events: events,
                           threadNodes: [threadNode])
     }

    private static func generateFlameNode(
      events: [Event],
      stacks: [Stack],
      syms: SymbolicationResult) -> (FlameNode, [Double], String)
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
        let folded = samples.map { $0.description }.joined(separator: "\n")
        let node = FlameNode.fromSamples(samples)
        return (node, eventTimes, folded)
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
