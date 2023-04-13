//
//  Sample.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

public class Sample {
    public let stack: [Any]
    public var time: Double
    
    public init(time: Double, stack: [Any]) {
        self.time = time
        self.stack = stack
    }
    
//    func createCopy() -> Sample {
//        return Sample(time: self.time, stack: self.stack)
//    }
    
    public var description: String {
        let timeStr = String(format: "%.15f", self.time).replacingOccurrences(of: "0*$", with: "", options: .regularExpression)
        let stackStr = stack.map { s in
            if let array = s as? Array<Any> {
                return "\(array[0])"
            }
            return "\(s)"
        }.joined(separator: ";")
        return "\(stackStr) \(timeStr)"
    }
}
