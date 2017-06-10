//
//  SmearSwift3Tests.swift
//  SmearSwift3Tests
//
//  Created by Adam Jensen on 6/7/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import XCTest
@testable import SmearSwift3

class DataTests: XCTestCase {
    
    func testWhenDataContainsNeedleAtStart_thenReturnsSingleRange() {
        let needle = Data(bytes: [0, 0, 0, 1])
        let haystack = Data(bytes: [0, 0, 0, 1, 9, 9, 9, 9])
        
        let ranges = haystack.ranges(of: needle)
        
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first!, Range(uncheckedBounds: (lower: 0, upper: 4)))
    }
    
    func testWhenDataContainsNeedleInMiddle_thenReturnsOneRange() {
        let needle = Data(bytes: [0, 0, 0, 1])
        let haystack = Data(bytes: [8, 8, 8, 0, 0, 0, 1, 9, 9, 9, 9])
        
        let ranges = haystack.ranges(of: needle)
        
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first!, Range(uncheckedBounds: (lower: 3, upper: 7)))
    }
    
    func testWhenDataContainsNeedleAtEnd_thenReturnsOneRange() {
        let needle = Data(bytes: [0, 0, 0, 1])
        let haystack = Data(bytes: [9, 9, 9, 9, 0, 0, 0, 1])
        
        let ranges = haystack.ranges(of: needle)
        
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first!, Range(uncheckedBounds: (lower: 4, upper: 8)))
    }
    
    func testWhenDataContainsTwoNeedles_thenReturnsTwoRanges() {
        let needle = Data(bytes: [0, 0, 0, 1])
        let haystack = Data(bytes: [9, 9, 9, 9, 0, 0, 0, 1, 8, 0, 0, 0, 1])
        
        let ranges = haystack.ranges(of: needle)
        
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first!, Range(uncheckedBounds: (lower: 4, upper: 8)))
        XCTAssertEqual(ranges.last!, Range(uncheckedBounds: (lower: 9, upper: 13)))
    }
    
    func testWhenDataContainsNeedlesAtStartAndEnd_thenReturnsTwoRanges() {
        let needle = Data(bytes: [0, 0, 0, 1])
        let haystack = Data(bytes: [0, 0, 0, 1, 8, 0, 0, 0, 1])
        
        let ranges = haystack.ranges(of: needle)
        
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first!, Range(uncheckedBounds: (lower: 0, upper: 4)))
        XCTAssertEqual(ranges.last!, Range(uncheckedBounds: (lower: 5, upper: 9)))
    }
}
