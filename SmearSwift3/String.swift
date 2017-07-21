//
//  String.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 7/16/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import Foundation

extension String {
    func run() -> String? {
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", self]
        process.standardOutput = pipe
//        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        defer { fileHandle.closeFile() }
        process.launch()
        
        return String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8)
    }
    
    func runForSideEffects() {
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", self]
        process.standardOutput = pipe
//        process.standardError = pipe
        process.launch()
        process.waitUntilExit()
    }
}
