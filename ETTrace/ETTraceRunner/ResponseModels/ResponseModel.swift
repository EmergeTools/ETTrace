//
//  ResponseModel.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation
import Symbolicator

struct ResponseModel: Decodable {
    let osBuild: String
    let osVersion: String?
    let isSimulator: Bool
    let libraryInfo: LibraryInfo
    let cpuType: String
    let device: String
    let events: [Event]
    let threads: [String: Thread]
    let sampleRate: UInt32?
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
