//
//  AVCMonkey.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 6/9/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import Cocoa

struct AVCMonkey {
    let sourcePath: String
    let naluParser: NALUnitParser!
    var nalUnits: [NALUnit]
    var removedFrames: Set<Int>
    
    init?(path: String) throws {
        sourcePath = path
        naluParser = try NALUnitParser(path: sourcePath)
        nalUnits = naluParser.parse()
        removedFrames = Set<Int>()
    }
    
    func frameNumbersForIDRFrames() -> [Int] {
        let naluTypesForVideoFrames: [NALUnitType] = [
            .SliceLayerIDR,
            .SliceLayerNonIDR,
            .SliceDataA,
            .SliceDataB,
            .SliceDataC,
        ]
        var idrFrameIndices = [Int]()
        var index = 0
        for nalu in nalUnits {
            if nalu.type == .SliceLayerIDR {
                idrFrameIndices.append(index)
            }
            
            if naluTypesForVideoFrames.contains(nalu.type) {
                index += 1
            }
        }
        
        return idrFrameIndices
    }
    
    mutating func removeFrame(at index: Int) {
        removedFrames.insert(index)
    }
    
    mutating func removeFrames(indices: [Int]) {
        removedFrames.formUnion(indices)
    }
    
    func write(toFilePath sinkPath: String) {
        FileManager.default.createFile(atPath: sinkPath, contents: nil, attributes: nil)
        guard let sourceFileHandle = FileHandle(forReadingAtPath: sourcePath),
              let sinkFileHandle = FileHandle(forWritingAtPath: sinkPath)
        else {
            print("Failed to open source and sink for AVC write")
            return
        }
        
//        print("Writing \(nalUnits.count) units")
        var i = 0
        nalUnits.forEach { nalUnit in
//            print ("\(i): \(nalUnit.type)")
            
            let nalUnitData = sourceFileHandle.readData(ofLength: nalUnit.range.count)
            
            if !removedFrames.contains(i) {
                sinkFileHandle.write(nalUnitData)
            }
            
            i += 1
        }
        
        sinkFileHandle.synchronizeFile()
        sourceFileHandle.closeFile()
        sinkFileHandle.closeFile()
    }
}
