//
//  NALUnitParserTests.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 6/9/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import XCTest
@testable import SmearSwift3

class NALUnitParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: processNALUnitResidue

    func testWhenNALUnitResidueIsPresent_thenReturnsAssembledNALUnit() {
        let nalUnitType = NALUnitType.PictureParameterSet
        let previousChunk = Data(bytes: [0, 0, 0, 1, nalUnitType.rawValue, 9, 9])
        let haystack = Data(bytes: [9, 9, 9, 0, 0, 0, 1, 8, 8, 8])
        let residueRange = Range(uncheckedBounds: (0, 7))
        let residueData = previousChunk.subdata(in: residueRange)
        let firstStartCodeRangeInNextChunk = Range(uncheckedBounds: (0, 3))
        
        let residualNALUnit = NALUnitParser.processNALUnitResidue(
            startCodeLength: 4,
            residueRange: residueRange,
            residueData: residueData,
            firstStartCodeRangeInNextChunk: firstStartCodeRangeInNextChunk,
            chunk: haystack
        )
        
        XCTAssertNotNil(residualNALUnit)
        XCTAssertEqual(residualNALUnit!.range, Range(uncheckedBounds: (0, 10)))
        XCTAssertEqual(residualNALUnit!.type, nalUnitType)
    }

    func testWhenNALUnitResidueIsAbsent_thenDoesNotReturnNALUnit() {
        let haystack = Data(bytes: [0, 0, 0, 1, 8, 8, 8])
        let firstStartCodeRangeInNextChunk = Range(uncheckedBounds: (0, 3))
        
        let residualNALUnit = NALUnitParser.processNALUnitResidue(
            startCodeLength: 4,
            residueRange: nil,
            residueData: nil,
            firstStartCodeRangeInNextChunk: firstStartCodeRangeInNextChunk,
            chunk: haystack
        )
        
        XCTAssertNil(residualNALUnit)
    }
    
    // MARK: processWholeNALUnits
    
    func testWhenZeroCompleteNALUnitsExistInChunk_thenReturnsEmptyList() {
        let haystack = Data(bytes: [0, 0, 0, 1, 8, 8, 8])
        let startCodeRanges = haystack.ranges(of: Data.startCodeWithLength(4))
        
        let (wholeNALUnits, _) = NALUnitParser.processWholeNALUnits(chunk: haystack, startCodeRanges: startCodeRanges)
        
        XCTAssertTrue(wholeNALUnits.isEmpty)
    }
    
    func testWhenResidueExistsInChunk_thenReturnsResidueRange() {
        let haystack = Data(bytes: [0, 0, 0, 1, 8, 8, 8])
        let startCodeRanges = haystack.ranges(of: Data.startCodeWithLength(4))
        
        let (_, residueRange) = NALUnitParser.processWholeNALUnits(chunk: haystack, startCodeRanges: startCodeRanges)
        
        XCTAssertNotNil(residueRange)
        XCTAssertEqual(residueRange, Range<Int>(uncheckedBounds: (0, haystack.count)))
    }
    
    func testWhenCompleteNALUnitExistsInChunk_thenReturnsNALUnitAndResidue() {
        let nalUnitType = NALUnitType.EndOfSequence
        let haystack = Data(bytes: [0, 0, 0, 1, nalUnitType.rawValue, 8, 8, 0, 0, 0, 1])
        let startCodeRanges = haystack.ranges(of: Data.startCodeWithLength(4))
        
        let (wholeNALUnits, residueRange) = NALUnitParser.processWholeNALUnits(chunk: haystack, startCodeRanges: startCodeRanges)
        
        let nalUnit = NALUnit(type: nalUnitType, range: Range<Int>(uncheckedBounds: (0, 7)))
        
        XCTAssertEqual(wholeNALUnits.count, 1)
        XCTAssertEqual(wholeNALUnits.first!.type, nalUnit.type)
        XCTAssertEqual(wholeNALUnits.first!.range, nalUnit.range)
        XCTAssertNotNil(residueRange)
        XCTAssertEqual(residueRange, Range<Int>(uncheckedBounds: (7, haystack.count)))
    }
    
    func testWhenTwoCompleteNALUnitsExistInChunk_thenReturnsTwoNALUnitsAndResidue() {
        let nalUnit1Type = NALUnitType.EndOfSequence
        let nalUnit2Type = NALUnitType.AccessUnitDelimiter
        let haystack = Data(bytes: [0, 0, 0, 1, nalUnit1Type.rawValue, 8, 8, 0, 0, 0, 1, nalUnit2Type.rawValue, 10, 10, 10, 0, 0, 0, 1])
        let startCodeRanges = haystack.ranges(of: Data.startCodeWithLength(4))
        
        let (wholeNALUnits, residueRange) = NALUnitParser.processWholeNALUnits(chunk: haystack, startCodeRanges: startCodeRanges)
        
        let nalUnit1 = NALUnit(type: nalUnit1Type, range: Range<Int>(uncheckedBounds: (0, 7)))
        let nalUnit2 = NALUnit(type: nalUnit2Type, range: Range<Int>(uncheckedBounds: (7, 15)))
        
        XCTAssertEqual(wholeNALUnits.count, 2)
        XCTAssertEqual(wholeNALUnits.first!.type, nalUnit1.type)
        XCTAssertEqual(wholeNALUnits.first!.range, nalUnit1.range)
        XCTAssertEqual(wholeNALUnits.last!.type, nalUnit2.type)
        XCTAssertEqual(wholeNALUnits.last!.range, nalUnit2.range)
        XCTAssertNotNil(residueRange)
        XCTAssertEqual(residueRange, Range<Int>(uncheckedBounds: (15, haystack.count)))
    }
    
    // TODO: Test when we're splitting the start code across buffer boundaries
}
