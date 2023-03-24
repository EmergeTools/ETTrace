//
//  main.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import ArgumentParser

@main
struct PerfAnalysisRunner: ParsableCommand {
    @Option(name: .shortAndLong, help: "Directory with dSYMs")
    var dsyms: String? = nil
    
    @Flag(name: .shortAndLong, help: "Relaunch app with profiling from startup.")
    var launch = false

    @Flag(name: .shortAndLong, help: "Use simulator")
    var useSimulator: Bool = false

    mutating func run() throws {
        let helper = RunnerHelper(dsyms, launch, useSimulator)
        Task {
            do {
                try await helper.start()
            } catch let error {
                #if DEBUG
                print("PerfAnalysis crashed: \(error)")
                #endif
            }
            PerfAnalysisRunner.exit()
        }
        
        RunLoop.main.run()
    }
}
