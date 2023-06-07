//
//  File.swift
//  
//
//  Created by Itay Brenner on 6/6/23.
//

import Foundation
import ETModels

class JSONWrapper {
    static func toDictionary(_ node: FlameNode) -> NSDictionary {
        var children: NSObject
        if node.children.count == 1 {
            children = toDictionary(node.children[0])
        } else {
            let childArray = NSMutableArray()
            for c in node.children {
                childArray.add(toDictionary(c))
            }
            children = childArray
        }
        
        return [
            "name": node.name,
            "start": node.start,
            "duration": node.duration,
            "library": node.library ?? "",
            "children": children
        ]
    }
    
    static func toData(_ input: FlameNode) -> Data? {
        let jsonObject = toDictionary(input)
        return try? JSONSerialization.data(withJSONObject: jsonObject, options: .withoutEscapingSlashes)
    }
}
