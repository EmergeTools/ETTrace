//
//  Models.swift
//
//
//  Created by Noah Martin on 11/7/23.
//

import Foundation

struct ResponseModel: Decodable {
    let osBuild: String
    let osVersion: String?
    let isSimulator: Bool
    let libraryInfo: LibraryInfo
    let cpuType: String
    let device: String
    let events: [Event]
    let threads: [String: Thread]
}

struct LibraryInfo: Decodable {
    let relativeTime: Double
    let mainThreadId: Int
    let loadedLibraries: [LoadedLibrary]
}

struct Thread: Decodable {
    let name: String
    let stacks: [Stack]
}

struct Event: Decodable {
    let span: String
    let type: EventType
    let time: Double
}

enum EventType: String, Decodable {
    case start
    case stop
}

struct LoadedLibrary: Decodable, Equatable, Hashable {
    let path: String
    let loadAddress: UInt64
    let uuid: String
}

struct Stack: Decodable {
    let stack: [UInt64]
    let time: Double
}
