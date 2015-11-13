//
//  BundleFileUpdater.swift
//
//  Created by Michael Kamphausen on 12.11.15.
//  Copyright © 2015 apploft GmbH. All rights reserved.
//

import Foundation

/// updates bundle files
public class BundleFileUpdater {
    
    public static let BundleFileUpdaterErrorDomain = "BundleFileUpdaterErrorDomain"
    
    private static let codeToReason = ["initialization failed", "downloaded file has no changes or is empty"]
    private static let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first
    
    private class func replaceText(text: String, replacingTexts: [String: String]) -> String {
        var text = text
        
        for (target, replacement) in replacingTexts {
            text = text.stringByReplacingOccurrencesOfString(target, withString: replacement)
        }
        
        return text
    }
    
    /**
     get the file url for an updatable bundle file that is managed by this class in the document directory
     - parameter filename: name of the file including extension
     - returns: NSURL for a file with the given `filename` in the document directory using the `file://` scheme
     */
    public class func urlForFile(filename: String) -> NSURL? {
        guard let documentsPath = documentsPath else {
            return nil
        }
        return NSURL(string: "file://" + documentsPath)?.URLByAppendingPathComponent(filename)
    }
    
    /**
     get the file url for an updatable bundle file that is managed by this class in the document directory
     - parameter filename: name of the file including extension
     - parameter url: name of the file including extension
     - parameter replacingTexts: name of the file including extension
     - parameter didReplaceFile: name of the file including extension
     - returns: NSURL for a file with the given `filename` in the document directory using the `file://` scheme
     */
    public class func updateFile(filename: String, url: String, replacingTexts: [String: String] = [:], didReplaceFile: ((destinationURL: NSURL?, error: NSError?) -> ())? = nil) -> NSURL? {
        let fileManager = NSFileManager.defaultManager()
        let destinationText: String
        
        guard let url = NSURL(string: url),
            bundleURL = NSBundle.mainBundle().URLForResource(filename, withExtension: nil),
            bundlePath = bundleURL.path,
            bundleFileModifiedDate = (try? fileManager.attributesOfItemAtPath(bundlePath)[NSFileModificationDate]) as? NSDate,
            documentsPath = documentsPath,
            destinationURL = NSURL(string: "file://" + documentsPath)?.URLByAppendingPathComponent(filename),
            destinationPath = destinationURL.path else {
                didReplaceFile?(destinationURL: nil, error: NSError(code: 0))
                return nil
        }
        
        do {
            let destinationFileModifiedDate = (try? fileManager.attributesOfItemAtPath(destinationPath)[NSFileModificationDate]) as? NSDate
            if (destinationFileModifiedDate == nil) || (bundleFileModifiedDate.compare(destinationFileModifiedDate!) == .OrderedDescending) {
                let bundleText = try String(contentsOfFile: bundlePath)
                try replaceText(bundleText, replacingTexts: replacingTexts).writeToFile(destinationPath, atomically: true, encoding: NSUTF8StringEncoding)
                destinationText = try String(contentsOfFile: destinationPath)
                didReplaceFile?(destinationURL: destinationURL, error: nil)
            } else {
                destinationText = try String(contentsOfFile: destinationPath)
            }
        } catch let error as NSError {
            didReplaceFile?(destinationURL: destinationURL, error: error)
            return destinationURL
        }
        
        
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        
        let task = session.dataTaskWithURL(url) { (data, response, error) in
            guard error == nil,
                let data = data else {
                    didReplaceFile?(destinationURL: destinationURL, error: error)
                    return
            }
            
            let text = replaceText(String(data: data, encoding: NSUTF8StringEncoding) ?? "", replacingTexts: replacingTexts)
            if !text.isEmpty && (text != destinationText) {
                do {
                    try text.writeToFile(destinationPath, atomically: true, encoding: NSUTF8StringEncoding)
                    didReplaceFile?(destinationURL: destinationURL, error: nil)
                } catch let error as NSError {
                    didReplaceFile?(destinationURL: destinationURL, error: error)
                }
            } else {
                didReplaceFile?(destinationURL: destinationURL, error: NSError(code: 1))
            }
        }
        task.resume()
        
        return destinationURL
    }
    
    private class func updateBundleFile(filepath: String, url: String, completion: (String) -> ()) {
        guard let url = NSURL(string: url) else {
            return completion("invalid url for file '\(filepath)'")
        }
        
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        
        let task = session.dataTaskWithURL(url) { (data, response, error) in
            guard error == nil,
                let data = data else {
                    return completion("download for file '\(filepath)' failed with error: \(error)")
            }
            
            let text = String(data: data, encoding: NSUTF8StringEncoding) ?? ""
            let destinationText = try? String(contentsOfFile: filepath) ?? ""
            
            if !text.isEmpty && (text != destinationText) {
                do {
                    try text.writeToFile(filepath, atomically: true, encoding: NSUTF8StringEncoding)
                    completion("successfully updated file '\(filepath)'")
                } catch let error as NSError {
                    completion("writing to file '\(filepath)' failed with error: \(error)")
                }
            } else {
                completion("downloaded file has no changes or is empty for file '\(filepath)'")
            }
        }
        task.resume()
    }
    
    /**
     get the file url for an updatable bundle file that is managed by this class in the document directory
     - parameter files: name of the file including extension
     - warning: never call this method from app code as it calls `exit()`. It is designated to be called from a command line script
     */
    public class func updateBundleFilesFromCLI(files: [String: String]) {
        let group = dispatch_group_create()
        
        for (filepath, url) in files {
            dispatch_group_enter(group)
            updateBundleFile(filepath, url: url) { (message) in
                print(message)
                dispatch_group_leave(group)
            }
        }
        
        dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            exit(0)
        }
        
        NSRunLoop.currentRunLoop().run()
    }

}

private extension NSError {
    
    convenience init(code: Int) {
        let reason = code < BundleFileUpdater.codeToReason.count ? BundleFileUpdater.codeToReason[code] : "unknown reason"
        self.init(domain: BundleFileUpdater.BundleFileUpdaterErrorDomain, code: code, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
    }
    
}
