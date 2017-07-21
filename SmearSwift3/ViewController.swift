//
//  ViewController.swift
//  Smear
//
//  Created by Adam Jensen on 6/7/17.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    @IBOutlet weak var sourcePathControl: NSPathControl!
    @IBOutlet weak var shredButton: NSButtonCell!
    @IBOutlet weak var collectionView: NSCollectionView!
    
    fileprivate var avcMonkey: AVCMonkey?
    fileprivate var sourceAsset: AVAsset?
    fileprivate var sourceVideoTrack: AVAssetTrack?
    fileprivate var frameTimes: [Int: CMTime]?
    fileprivate var keyFrameIndices: [Int]?
    fileprivate var imageGenerator: AVAssetImageGenerator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nib = NSNib(nibNamed: "NSCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: "FrameViewItem")
        
        sourcePathControl.url = URL(string: NSString(string: "~/Desktop").expandingTildeInPath)
    }
    
    @IBAction func sourcePathChanged(_ sender: Any) {
        guard let url = URL(string: sourcePathControl.stringValue) else {
            print("Couldn't parse source URL")
            return
        }
        let asset = AVAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
            print("Couldn't find video track in asset")
            return
        }
        
        let sourceFilePath = sourcePathControl.stringValue.replacingOccurrences(of: "file://", with: "")
        
        print("Demuxing source video")
        
        try? FileManager.default.removeItem(atPath: "/tmp/smear.h264")
        try? FileManager.default.removeItem(atPath: "/tmp/smear.aac")
        
        "/usr/local/bin/mp4box -raw 1 \(sourceFilePath) -out /tmp/smear.h264".runForSideEffects()
        "/usr/local/bin/mp4box -raw 2 \(sourceFilePath) -out /tmp/smear.aac".runForSideEffects()
        
        do {
            print("Parsing video track")
            if let avcMonkey = try AVCMonkey(path: "/tmp/smear.h264") {
                self.avcMonkey = avcMonkey
                
                imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator?.maximumSize = CGSize(width: 50, height: 50)
                sourceAsset = asset
                sourceVideoTrack = videoTrack
                frameTimes = asset.frameTimesForTrack(track: videoTrack)
                print("Found \(frameTimes!.count) frames")
                
                keyFrameIndices = avcMonkey.frameNumbersForIDRFrames()
                print("Found \(keyFrameIndices!.count) key frames")
                
                collectionView.reloadData()
                
                shredButton.isEnabled = true
            }
        } catch let error {
            print(error)
            return
        }
    }
    
    @IBAction func shredButtonClicked(_ sender: Any) {
        guard let keyFrameIndices = keyFrameIndices else {
            assert(false, "No key frame indices available")
            return
        }
        guard var avcMonkey = avcMonkey else {
            assert(false, "No AVCMonkey instance")
            return
        }
        
        let rawIndicesForKeyFrames = collectionView.selectionIndexPaths.map { keyFrameIndices[$0.item] }
        rawIndicesForKeyFrames.forEach { index in
            avcMonkey.removeFrame(at: index)
        }
        
        avcMonkey.write(toFilePath: "/tmp/smear-new.h264")
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "output.mp4"
        panel.begin { result in
            if result == NSFileHandlingPanelOKButton, let url = panel.url {
                let destinationPath = url.absoluteString.replacingOccurrences(of: "file://", with: "")
                
                if FileManager.default.fileExists(atPath: destinationPath) {
                    try! FileManager.default.removeItem(atPath: destinationPath)
                }
                
                print("Writing to \(destinationPath)")
                "/usr/local/bin/mp4box -add /tmp/smear-new.h264 -add /tmp/smear.aac \(destinationPath)".runForSideEffects()
            }
        }
    }
}

extension ViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let viewItem = collectionView.makeItem(withIdentifier: "FrameViewItem", for: indexPath)
        
        if let frameTimes = frameTimes, let keyFrameIndices = keyFrameIndices, let nearestTimeToFrame = frameTimes[keyFrameIndices[indexPath.item]] {
//            print("Request image for \(indexPath.item)")
            
            if viewItem.imageView?.tag != indexPath.item {
                viewItem.imageView?.tag = indexPath.item
                imageGenerator?.generateCGImagesAsynchronously(forTimes: [NSValue(time: nearestTimeToFrame)], completionHandler: { (requestedTime, image, actualTime, resultCode, error) in
                    if error != nil {
                        print("Failed to get thumbnail at time \(requestedTime)")
                    } else {
//                        print("Got thumbnail at time \(requestedTime)")
                    }
                    
                    DispatchQueue.main.async {
//                        print("Looking for \(indexPath) in \(collectionView.selectionIndexPaths)")
                        if collectionView.selectionIndexPaths.contains(indexPath) {
                            viewItem.view.layer?.backgroundColor = CGColor.black
                        } else {
                            viewItem.view.layer?.backgroundColor = CGColor.clear
                        }
                        
                        if let imageView = viewItem.imageView, imageView.tag == indexPath.item {
                            if let image = image {
                                imageView.image = NSImage(cgImage: image, size: CGSize(width: 100, height: 100))
                            } else {
                                imageView.image = nil
                            }
                        }
                    }
                })
            }
        } else {
            viewItem.imageView?.tag = -1
            viewItem.imageView?.image = nil
        }
        return viewItem
    }
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return keyFrameIndices?.count ?? 0
    }
    
}

extension ViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        for indexPath in indexPaths {
            if let item = collectionView.item(at: indexPath) {
                item.view.layer?.backgroundColor = NSColor.alternateSelectedControlColor.cgColor
            }
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        for indexPath in indexPaths {
            if let item = collectionView.item(at: indexPath) {
                item.view.layer?.backgroundColor = CGColor.clear
            }
        }
    }
}
