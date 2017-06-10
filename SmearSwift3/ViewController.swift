//
//  ViewController.swift
//  Smear
//
//  Created by Adam Jensen on 6/7/17.
//

import Cocoa

class ViewController: NSViewController {
    var avcMonkey: AVCMonkey!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            avcMonkey = try AVCMonkey(path: "/tmp/out.avc")
        } catch let error {
            print(error)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

struct AVCMonkey {
    let naluParser: NALUnitParser!
    
    init?(path: String) throws {
        naluParser = try NALUnitParser(path: path)
        naluParser.parse()
        print(naluParser.nalUnits)
    }
}
