//
//  AVCMonkeyTests.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 7/1/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import XCTest
@testable import SmearSwift3

class AVCMonkeyTests: XCTestCase {

    func testWhenGivenAnInputFileAndNoChangesToMake_thenWritesAnEquivalentOutputFile() {
        let inputPath = "/tmp/in.avc"
        let outputPath = "/tmp/out.avc"
        
        let avcMonkey = monkeyWithInputPath(inputPath)
        avcMonkey.write(toFilePath: outputPath)
        
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: inputPath, andPath: outputPath))
    }

    private func monkeyWithInputPath(_ inputPath: String) -> AVCMonkey {
        do {
            return try AVCMonkey(path: inputPath)!
        } catch {
            assert(false)
        }
    }
}
