//
//  Sample.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

public class Sample {
    public let stack: [(String?, String, UInt64?)]
    public var time: Double
    
    public init(time: Double, stack: [(String?, String, UInt64?)]) {
        self.time = time
        self.stack = stack
    }
    
    public var description: String {
        let timeStr = String(format: "%.15f", self.time).replacingOccurrences(of: "0*$", with: "", options: .regularExpression)
        let stackStr = stack.map { s in
            return "\(s.1)"
        }.joined(separator: ";")
        return "\(stackStr) \(timeStr)"
    }
}
