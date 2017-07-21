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
    
    init?() throws {
        filePath = "n/a"
        fileHandle = nil
        nalUnits = [NALUnit]()
        startCodeLength = 4
    }
    
    mutating func parse() -> [NALUnit] {
        var buffer = fileHandle.readData(ofLength: CHUNK_SIZE)
        
        while buffer.count > 0 {
            handleProcessChunkResult(processChunk(buffer))
        
            buffer = fileHandle.readData(ofLength: CHUNK_SIZE)
        }
        
        if let flushedNALUnit = flush() {
            nalUnits.append(flushedNALUnit)
        }
        
        return nalUnits
    }
    
    mutating func handleProcessChunkResult(_ result: (newNALUnits: [NALUnit], residueData: Data?, residueRange: Range<Int>?)) {
        nalUnits.append(contentsOf: result.newNALUnits)
        nalUnitResidueData = result.residueData
        nalUnitResidueRange = result.residueRange
    }
}

extension NALUnitParser {
    static func sniffStartCodeLength(_ fileHandle: FileHandle) throws -> Int {
        let sniffData = fileHandle.readData(ofLength: 1024)
        
        let startCodeLength: Int
        if let startRange = sniffData.range(of: Data.startCodeWithLength(4)) {
            startCodeLength = 4
            fileHandle.seek(toFileOffset: UInt64(startRange.lowerBound))
        } else if let startRange = sniffData.range(of: Data.startCodeWithLength(3)) {
            startCodeLength = 3
            fileHandle.seek(toFileOffset: UInt64(startRange.lowerBound))
        } else {
            throw NSError()
        }
        
        return startCodeLength
    }
    
    func processChunk(_ chunk: Data) -> ([NALUnit], Data?, Range<Int>?) {
        var newNALUnits = [NALUnit]()
        var nalUnitResidueData: Data?
        var nalUnitResidueRange: Range<Int>?
        let startCodeRanges = chunk.ranges(of: Data.startCodeWithLength(startCodeLength))
        
        let (residualNALUnits, remainingResidueData, remainingResidueRange) = NALUnitParser.processNALUnitResidue(
            startCodeLength: startCodeLength,
            residueRange: self.nalUnitResidueRange,
            residueData: self.nalUnitResidueData,
            firstStartCodeRangeInNextChunk: startCodeRanges.first,
            chunk: chunk
        )
        
        if let residualNALUnits = residualNALUnits {
            newNALUnits.append(contentsOf: residualNALUnits)
        }
        
        if let remainingResidueData = remainingResidueData, let remainingResidueRange = remainingResidueRange {
            nalUnitResidueData = remainingResidueData
            nalUnitResidueRange = remainingResidueRange
        } else {
            // TODO: Sort out range in overall stream vs range in current chunk
            let (wholeNALUnits, residueRange) = NALUnitParser.processWholeNALUnits(chunk: chunk, startCodeRanges: startCodeRanges)
            newNALUnits.append(contentsOf: wholeNALUnits)
            
            nalUnitResidueRange = residueRange
            if let residueRange = residueRange {
                nalUnitResidueData = chunk.subdata(in: residueRange)
            } else {
                nalUnitResidueData = nil
            }
        }
        
        return (newNALUnits, nalUnitResidueData, nalUnitResidueRange)
    }
    
    func flush() -> NALUnit? {
        if let nalUnitResidueData = nalUnitResidueData,
           let nalUnitResidueRange = nalUnitResidueRange,
           nalUnitResidueRange.count >= startCodeLength + 1 {
            let nalUnitBytes = [UInt8](nalUnitResidueData as Data)
            let packetType = nalUnitBytes[startCodeLength]
            let nalUnitRawType = NALUnitParser.nalUnitType(fromPacketType: packetType)
            if let nalUnitType = NALUnitType(rawValue: nalUnitRawType) {
                return NALUnit(type: nalUnitType, range: nalUnitResidueRange)
            } else {
                print("Failed to determine NAL unit type during flush")
            }
        }
        
        return nil
    }
    
    static func processNALUnitResidue(startCodeLength: Int, residueRange: Range<Int>?, residueData: Data?, firstStartCodeRangeInNextChunk: Range<Int>?, chunk: Data) -> ([NALUnit]?, Data?, Range<Int>?) {
        guard
            let residueData = residueData,
            let residueRange = residueRange
        else {
            return (nil, nil, nil)
        }
        
        let unprocessedData = NSMutableData(data: residueData)
        
        if let firstStartCodeRangeInNextChunk = firstStartCodeRangeInNextChunk {
            let rangeForRemainderOfResidualNALUnit = Range<Int>(uncheckedBounds: (0, firstStartCodeRangeInNextChunk.lowerBound))
            unprocessedData.append(chunk.subdata(in: rangeForRemainderOfResidualNALUnit))
            
            let startCodeRanges = (unprocessedData as Data).ranges(of: Data.startCodeWithLength(startCodeLength))
            let (wholeNALUnits, residueRange) = processWholeNALUnits(chunk: unprocessedData as Data, startCodeRanges: startCodeRanges)
            
            if let residueRange = residueRange {
                let nalUnitRange = Range(uncheckedBounds: (residueRange.lowerBound, residueRange.lowerBound + unprocessedData.length))
                let nalUnitBytes = [UInt8](unprocessedData as Data)
                
                let packetType = nalUnitBytes[startCodeLength]
                let nalUnitRawType = nalUnitType(fromPacketType: packetType)
                
                if let nalUnitType = NALUnitType(rawValue: nalUnitRawType) {
//                    print("Saw NALU of type \(nalUnitType)")
                    let residualNALUnit = NALUnit(type: nalUnitType, range: nalUnitRange)
                    var nalUnits = [NALUnit](wholeNALUnits)
                    nalUnits.append(residualNALUnit)
                    return (nalUnits, nil, nil)
                } else {
                    print("Failed to determine NAL unit type")
                }
            } else {
                // TODO
                print("What now?")
                assert(false)
            }
        } else {
            unprocessedData.append(chunk)
            let unprocessedRange = Range<Int>(uncheckedBounds: (residueRange.lowerBound, residueRange.count + chunk.count))
            return (nil, unprocessedData as Data, unprocessedRange)
        }
    
        return (nil, nil, nil)
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
                    let packetType = chunk.withUnsafeBytes { ptr -> UInt8 in
                        return ptr[nalUnitRange.lowerBound + currentRange.count]
                    }
                    let nalUnitRawType = nalUnitType(fromPacketType: packetType)
                    if let nalUnitType = NALUnitType(rawValue: nalUnitRawType) {
//                        print("Saw NALU of type \(nalUnitType)")
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
    
    static func nalUnitType(fromPacketType packetType: UInt8) -> UInt8 {
        return packetType & 0b00011111
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
    static func startCodeWithLength(_ length: Int) -> Data {
        var startCode = Array<UInt8>(repeating: 0, count: length)
        startCode[length - 1] = 1
        return Data(bytes: startCode)
    }
}
