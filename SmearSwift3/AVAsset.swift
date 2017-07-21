//
//  AVAsset.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 7/3/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import AVFoundation

extension AVAsset {
    func frameTimesForTrack(track: AVAssetTrack) -> [Int: CMTime] {
        // Using `nil` outputSettings avoids decompression overhead
        guard let reader = try? AVAssetReader(asset: self) else {
            print("Couldn't read asset")
            return [:]
        }
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()
        
        var frameTimes = [Int: CMTime]()
        var frameNumber = 0
        while reader.status == .reading {
            if let sampleBuffer = output.copyNextSampleBuffer(), CMSampleBufferIsValid(sampleBuffer) && CMSampleBufferGetTotalSampleSize(sampleBuffer) != 0 {
                let frameTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                if frameTime.isValid {
                    frameTimes[frameNumber] = frameTime
                    frameNumber += 1
                }
            }
        }
        
        return frameTimes
    }
}
