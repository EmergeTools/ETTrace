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
    
    @Option(name: .shortAndLong, help: "App BundleId")
    var bundleId: String
    
    @Flag(name: .shortAndLong, help: "Relaunch app with profiling from startup.")
    var launch = false

    @Option(name: [.customShort("i"), .long], help: "Simulator UUID") // -i
    var uuid: String? = nil

    mutating func run() throws {
        let helper = RunnerHelper(dsyms, bundleId, launch, uuid)
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
