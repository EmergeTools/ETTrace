//
//  ResponseModel.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

struct ResponseModel: Decodable {
    let osBuild: String
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

struct LoadedLibrary: Decodable, Equatable, Hashable {
    let path: String
    let loadAddress: UInt64
    let uuid: String
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

struct Thread: Decodable {
    let name: String
    let stacks: [Stack]
}

struct Stack: Decodable {
    let stack: [UInt64]
    let time: Double
}
