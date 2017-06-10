//
//  NALUnitParser.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 6/9/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import Foundation

struct NALUnitParser {
    var nalUnits: [NALUnit]
    
    private let filePath: String
    private let fileHandle: FileHandle!
    
    fileprivate let startCodeLength: Int
    fileprivate var nalUnitResidueRange: Range<Int>?
    fileprivate var nalUnitResidueData: Data?
    
    private let CHUNK_SIZE = 16384 // TODO: Empirically pick a good chunk size
    
    init?(path: String) throws {
        filePath = path
        let url = URL(fileURLWithPath: path)
        fileHandle = try FileHandle(forReadingFrom: url)
        nalUnits = [NALUnit]()
        startCodeLength = try NALUnitParser.sniffStartCodeLength(fileHandle)
    }
    
    mutating func parse() {
        var buffer = fileHandle.readData(ofLength: CHUNK_SIZE)
        
        while buffer.count > 0 {
            processChunk(buffer)
            buffer = fileHandle.readData(ofLength: CHUNK_SIZE)
        }
    }
}

extension NALUnitParser {
    static func sniffStartCodeLength(_ fileHandle: FileHandle) throws -> Int {
        let startingPosition = fileHandle.offsetInFile
        
        fileHandle.seek(toFileOffset: 0)
        let startCodeData = fileHandle.readData(ofLength: 4)
        
        let startCodeLength: Int
        if startCodeData.starts(with: Data.startCodeWithLength(3)) {
            startCodeLength = 3
        } else if startCodeData.starts(with: Data.startCodeWithLength(4)) {
            startCodeLength = 4
        } else {
            throw NSError()
        }
        
        fileHandle.seek(toFileOffset: startingPosition)
        return startCodeLength
    }
    
    
    mutating func processChunk(_ chunk: Data) {
        var newNALUnits = [NALUnit]()
        let startCodeRanges = chunk.ranges(of: Data.startCodeWithLength(startCodeLength))
        
        if let residualNALUnit = NALUnitParser.processNALUnitResidue(
            startCodeLength: startCodeLength,
            residueRange: nalUnitResidueRange,
            residueData: nalUnitResidueData,
            firstStartCodeRangeInNextChunk: startCodeRanges.first,
            chunk: chunk
        ) {
            newNALUnits.append(residualNALUnit)
        }
        
        let (wholeNALUnits, residueRange) = NALUnitParser.processWholeNALUnits(chunk: chunk, startCodeRanges: startCodeRanges)
        newNALUnits.append(contentsOf: wholeNALUnits)
        
        nalUnitResidueRange = residueRange
        if let residueRange = residueRange {
            nalUnitResidueData = chunk.subdata(in: residueRange)
        } else {
            nalUnitResidueData = nil
        }
    }
    
    // TODO: typealias Range<Int>
    
    static func processNALUnitResidue(startCodeLength: Int, residueRange: Range<Int>?, residueData: Data?, firstStartCodeRangeInNextChunk: Range<Int>?, chunk: Data) -> NALUnit? {
        if let residueRange = residueRange,
            let residueData = residueData,
            let firstNALUnitRangeInNextChunk = firstStartCodeRangeInNextChunk {
            let nalUnitData = NSMutableData(data: residueData)
            nalUnitData.append(chunk.subdata(in: firstNALUnitRangeInNextChunk))
            
            let nalUnitRange = Range(uncheckedBounds: (lower: residueRange.lowerBound, upper: residueRange.lowerBound + nalUnitData.length))
            let nalUnitBytes = [UInt8](nalUnitData as Data)
            
            if let nalUnitType = NALUnitType(rawValue: nalUnitBytes[startCodeLength]) {
                return NALUnit(type: nalUnitType, range: nalUnitRange)
            } else {
                print("Failed to determine NAL unit type")
            }
        }
        
        return nil
    }
    
    static func processWholeNALUnits(chunk: Data, startCodeRanges: [Range<Int>]) -> ([NALUnit], Range<Int>?) {
        var wholeNALUnits = [NALUnit]()
        var residueRange: Range<Int>?
        
        if startCodeRanges.count > 0 {
            for index in 0...(startCodeRanges.count - 1) {
                let currentRange = startCodeRanges[index]
                
                if index + 1 == startCodeRanges.count {
                    residueRange = Range<Int>(uncheckedBounds: (currentRange.lowerBound, chunk.count))
                } else {
                    let nextRange = startCodeRanges[index + 1]
                    let nalUnitRange = Range<Int>(uncheckedBounds: (currentRange.lowerBound, nextRange.lowerBound))
                    let nalUnitRawType = chunk.withUnsafeBytes { ptr -> UInt8 in
                        return ptr[nalUnitRange.lowerBound + 4]
                    }
                    if let nalUnitType = NALUnitType(rawValue: nalUnitRawType) {
                        let nalUnit = NALUnit(type: nalUnitType, range: nalUnitRange)
                        wholeNALUnits.append(nalUnit)
                    } else {
                        print("Failed to determine NAL unit type: \(nalUnitRawType)")
                    }
                }
            }
        } else {
            residueRange = Range<Int>(uncheckedBounds: (0, chunk.count))
        }
        
        return (wholeNALUnits, residueRange)
    }
}

struct NALUnit {
    let type: NALUnitType
    let range: Range<Int>
}

enum NALUnitType: UInt8 {
    case Unspecified_0 = 0,
    SliceLayerNonIDR = 1,
    SliceDataA = 2,
    SliceDataB = 3,
    SliceDataC = 4,
    SliceLayerIDR = 5,
    SupplementalEnhancementInformation = 6,
    SequenceParameterSet = 7,
    PictureParameterSet = 8,
    AccessUnitDelimiter = 9,
    EndOfSequence = 10,
    EndOfStream = 11,
    FillerData = 12,
    SPSExtension = 13,
    Prefix = 14,
    SubsetSPS = 15,
    Reserved_16 = 16,
    Reserved_17 = 17,
    Reserved_18 = 18,
    SliceLayerAux = 19,
    SliceExtension = 20,
    SliceDepth = 21,
    Reserved_22 = 22,
    Reserved_23 = 23,
    Unspecified_24 = 24,
    Unspecified_25 = 25,
    Unspecified_26 = 26,
    Unspecified_27 = 27,
    Unspecified_28 = 28,
    Unspecified_29 = 29,
    Unspecified_30 = 30,
    Unspecified_31 = 31
}

extension Data {
    func rangesOfNALUnits(startCodeLength: Int) -> [Range<Int>] {
        var ranges = [Range<Int>]()
        var nextStartCodeOffset: Int?
        let startCode = Data.startCodeWithLength(startCodeLength)
        
        nextStartCodeOffset = range(of: startCode)?.lowerBound
        
        while let offset = nextStartCodeOffset,
            let currentRange = range(of: startCode, options: Data.SearchOptions(), in: Range(uncheckedBounds: (lower: offset, upper: self.count - 1))) {
                ranges.append(Range<Int>(uncheckedBounds: (currentRange.lowerBound, currentRange.lowerBound + startCodeLength)))
                
                let nextRange = Range<Int>(uncheckedBounds: (currentRange.lowerBound + startCodeLength, currentRange.upperBound))
                nextStartCodeOffset = range(of: startCode, options: Data.SearchOptions(), in: nextRange)?.lowerBound
        }
        
        return ranges
    }
    
    static func startCodeWithLength(_ length: Int) -> Data {
        var startCode = Array<UInt8>(repeating: 0, count: length)
        startCode[length - 1] = 1
        return Data(bytes: startCode)
    }
}
