//
//  Models.swift
//
//
//  Created by Noah Martin on 11/7/23.
//

import Foundation

public struct Event: Decodable {
    public let span: String
    public let type: EventType
    public let time: Double
}

public enum EventType: String, Decodable {
    case start
    case stop
}

public struct LoadedLibrary: Decodable, Equatable, Hashable {
    public let path: String
    public let loadAddress: UInt64
    public let uuid: String
}

public struct Stack: Decodable {
    let stack: [UInt64]
    let time: Double
}
