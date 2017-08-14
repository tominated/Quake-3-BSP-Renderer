//
//  Q3EntityParser.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 13/8/17.
//  Copyright © 2017 Thomas Brunoli. All rights reserved.
//

import Foundation

let openBrace = CharacterSet.init(charactersIn: "{")
let closeBrace = CharacterSet.init(charactersIn: "}")
let quote = CharacterSet.init(charactersIn: "\"")

class Q3EntityParser {
    let scanner: Scanner

    init(entitiesString: String) {
        scanner = Scanner(string: entitiesString)
    }

    func parse() -> Array<Dictionary<String, String>> {
        var entities = Array<Dictionary<String, String>>()

        while scanner.scanCharacters(from: openBrace, into: nil) {
            entities.append(parseEntity())
        }

        return entities
    }

    private func parseEntity() -> Dictionary<String, String> {
        var entity = Dictionary<String, String>()

        while !scanner.scanCharacters(from: closeBrace, into: nil) {
            var rawKey: NSString?
            var rawValue: NSString?

            scanner.scanCharacters(from: quote, into: nil)
            scanner.scanUpToCharacters(from: quote, into: &rawKey)
            scanner.scanString("\" \"", into: nil)
            scanner.scanUpToCharacters(from: quote, into: &rawValue)
            scanner.scanCharacters(from: quote, into: nil)

            if let key = rawKey, let value = rawValue {
                entity[key as String] = value as String
            }
        }

        return entity
    }
}
