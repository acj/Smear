//
//  Data.swift
//  SmearSwift3
//
//  Created by Adam Jensen on 6/9/17.
//  Copyright © 2017 Adam Jensen. All rights reserved.
//

import Foundation

extension Data {
    func ranges(of searchData: Data) -> [Range<Int>] {
        var ranges = [Range<Int>]()
        var nextRange: Range<Int>?
        
        nextRange = range(of: searchData)
        
        while let currentRange = nextRange {
            ranges.append(currentRange)
            
            let restOfBufferRange = Range(uncheckedBounds: (currentRange.lowerBound + searchData.count, self.count))
            nextRange = range(of: searchData, options: Data.SearchOptions(), in: restOfBufferRange)
        }
        
        return ranges
    }
}
