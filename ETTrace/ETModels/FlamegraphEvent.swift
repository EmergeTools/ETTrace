//
//  File.swift
//  
//
//  Created by Itay Brenner on 28/6/23.
//

import Foundation

@objc
public class FlamegraphEvent: NSObject {
    @objc
    public let name: String
    
    @objc
    public let type: String
    
    @objc
    public let time: Double
    
    public init(name: String, type: String, time: Double) {
        self.name = name
        self.type = type
        self.time = time
    }
}
