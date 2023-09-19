//
//  ETTrace.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import ArgumentParser

struct ETTrace: ParsableCommand {
    @Option(name: .shortAndLong, help: "Directory with dSYMs")
    var dsyms: String? = nil
    
    @Flag(name: .shortAndLong, help: "Relaunch app with profiling from startup.")
    var launch = false

    @Flag(name: .shortAndLong, help: "Use simulator")
    var simulator: Bool = false
  
    @Flag(name: .shortAndLong, help: "Verbose logging")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Record all threads")
    var multiThread: Bool = false

    mutating func run() throws {
      if let dsym = dsyms, dsym.hasSuffix(".dSYM") {
        ETTrace.exit(withError: ValidationError("The dsym argument should be set to a folder containing your dSYM files, not the dSYM itself"))
      }
        let helper = RunnerHelper(dsyms, launch, simulator, verbose, multiThread)
        Task {
            do {
                try await helper.start()
            } catch let error {
                print("ETTrace error: \(error)")
            }
          ETTrace.exit()
        }
        
        RunLoop.main.run()
    }
}
