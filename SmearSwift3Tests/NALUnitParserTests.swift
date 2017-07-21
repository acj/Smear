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
    
    // MARK: processNALUnitResidue
    
    func testWhenNoNALUnitResidueIsPresent_thenDoesNotReturnNALUnit() {
        let (residualNALUnits, remainingResidueData, remainingResidueRange) = NALUnitParser.processNALUnitResidue(
            startCodeLength: 4,
            residueRange: nil,
            residueData: nil,
            firstStartCodeRangeInNextChunk: nil,
            chunk: Data()
        )
        
        XCTAssertNil(residualNALUnits)
        XCTAssertNil(remainingResidueData)
        XCTAssertNil(remainingResidueRange)
    }

    func testWhenNALUnitResidueIsPresent_thenReturnsAssembledNALUnit() {
        let nalUnitType = NALUnitType.PictureParameterSet
        let previousChunk = Data(bytes: [0, 0, 0, 1, nalUnitType.rawValue, 9, 9])
        let haystack = Data(bytes: [9, 9, 9, 0, 0, 0, 1, 8, 8, 8])
        let residueRange = Range(uncheckedBounds: (0, 7))
        let residueData = previousChunk.subdata(in: residueRange)
        let firstStartCodeRangeInNextChunk = Range(uncheckedBounds: (3, 7))
        
        let (residualNALUnits, remainingResidueData, remainingResidueRange) = NALUnitParser.processNALUnitResidue(
            startCodeLength: 4,
            residueRange: residueRange,
            residueData: residueData,
            firstStartCodeRangeInNextChunk: firstStartCodeRangeInNextChunk,
            chunk: haystack
        )
        
        XCTAssertEqual(residualNALUnits!.count, 1)
        XCTAssertEqual(residualNALUnits!.first!.range, Range(uncheckedBounds: (0, 10)))
        XCTAssertEqual(residualNALUnits!.first!.type, nalUnitType)
        XCTAssertNil(remainingResidueData)
        XCTAssertNil(remainingResidueRange)
    }

    func testWhenNALUnitResidueIsAbsent_thenDoesNotReturnNALUnit() {
        let haystack = Data(bytes: [0, 0, 0, 1, 8, 8, 8])
        let firstStartCodeRangeInNextChunk = Range(uncheckedBounds: (0, 3))
        
        let (residualNALUnits, remainingResidueData, remainingResidueRange) = NALUnitParser.processNALUnitResidue(
            startCodeLength: 4,
            residueRange: nil,
            residueData: nil,
            firstStartCodeRangeInNextChunk: firstStartCodeRangeInNextChunk,
            chunk: haystack
        )
        
        XCTAssertNil(residualNALUnits)
        XCTAssertNil(remainingResidueData)
        XCTAssertNil(remainingResidueRange)
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
    
    func testWhenNALUnitStartCodeIsSplitAcrossChunkBoundaries_thenReturnsCompleteNALUnit() throws {
        let nalUnitType = NALUnitType.EndOfSequence
        let haystack1 = Data(bytes: [0, 0])
        let haystack2 = Data(bytes: [0, 1, nalUnitType.rawValue])
        
        var naluParser = try NALUnitParser()!
        naluParser.handleProcessChunkResult(naluParser.processChunk(haystack1))
        naluParser.handleProcessChunkResult(naluParser.processChunk(haystack2))
        
        XCTAssertEqual(naluParser.nalUnits.count, 0)
        
        let nalUnit = naluParser.flush()
        
        XCTAssertNotNil(nalUnit)
        XCTAssertEqual(nalUnit!.type, nalUnitType)
        XCTAssertEqual(nalUnit!.range, Range<Int>(uncheckedBounds: (0, 5)))
    }
}
