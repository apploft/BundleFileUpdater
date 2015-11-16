//
//  BundleFileUpdater.swift
//
//  Created by Michael Kamphausen on 12.11.15.
//  Copyright © 2015 apploft GmbH. All rights reserved.
//

import Foundation

/** 
 Deliver your app with up-to-date local resource files in your app bundle and update them dynamically from a remote url both with every build and dynamically at runtime. Your users will always have the latest resource files' version without the need for a new app submission.
 
 Call `updateBundleFilesFromCLI(files: [String: String])` in a _Build Run Script Phase_ to update your resource files automatically at build time.
 
 Use `updateFile(filename: String, url: String, replacingTexts: [String: String] = [:], didReplaceFile: ((destinationURL: NSURL?, error: NSError?) -> ())? = nil) -> NSURL?` from your app code to download a new version of your resource file if needed and use it instead of the file's version in your app bundle.
*/
public class BundleFileUpdater {
    
    /**
     Error domain for errors specific to BundleFileUpdater.
     
     Error Codes:
     - 0: initialization failed: a given `filename` could not be found in app bundle or his destination path in the document directory could not be resolved
     - 1: downloaded file has no changes or is empty
     */
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
     Keep a local file in the app bundle with the given `filename` up-to-date from two sources: from the app bundle and from a remote URL. Therefore an updatable copy of this file is automatically copied from the app bundle to the document directory which should be the single source of truth in your application. No need to reference the file from app bundle or the remote URL directly anywhere else except for this method call. Supports a simple and automatic string search and replace before updating the file from either source.
     - parameter filename: name of the file in the app bundle including file extension
     - parameter url: url of a remote version of the updatable file with the given `filename`. If the file contents have changed online and are not empty, the local file will be replaced by the downloaded remote file.
     - parameter replacingTexts: optional dictionary of strings in case some contents of the updated file need to be automatically replaced, e.g. references or links need to be changed from remote to local targets. The dictionary's key is the string being searched and the value is the key's replacement string.
     - parameter didReplaceFile: completion handler that is called in case of an update or an error. The completion handler is called with it's argument `error` being `nil` and `destinationURL` pointing to the updated file in documents directory using the `file://` scheme when the file in the document directory has been updated by a newer version of itself in the app bundle (newer modification date) or when it has been updated from the given `url` when the remote file content is not empty and differs from the local file content. In case of an error the `destinationURL` might be pointing to the old version of the file in document directory as long as the error did not occur during initialization and `error` is the NSError that has occured. The case when there was no need to update because nothing has changed is handled as error with `BundleFileUpdaterErrorDomain` and code 1.
     - returns: NSURL for the file with the given `filename` in the document directory using the `file://` scheme. Returns `nil` if the initialization failed.
     - warning: Remember that requesting URLs using http instead of https might be blocked by App Transport Security in iOS 9 and above.
     
     Example:
     ```swift
     let localFileURL = BundleFileUpdater.updateFile("about.html", url: "https://www.example.com/about.html", replacingTexts: ["href=\"/terms-of-service.html\"": "href=\"tos.html\""], didReplaceFile: { (destinationURL, error) in
         guard error == nil else {
            // an error occured or the remote file had no changes …
            return
         }
         // local file was updated from url or from app bundle (because of an app update) …
     })
     ```
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
    
    /**
     Get the file url for an updatable file that is managed by this class which is stored in the document directory
     - parameter filename: name of the file in the app bundle including file extension
     - returns: NSURL for the file with the given `filename` in the document directory using the `file://` scheme
     
     Example:
     ```swift
     let localFileURL = BundleFileUpdater.urlForFile("about.html")
     ```
     */
    public class func urlForFile(filename: String) -> NSURL? {
        guard let documentsPath = documentsPath else {
            return nil
        }
        return NSURL(string: "file://" + documentsPath)?.URLByAppendingPathComponent(filename)
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
     Update files in your project belonging to your app bundle from remote URLs in case their content has changed online and the new content is not empty.
     
     To do so, you should add a new file to your project (but not to any of your targets) where you specify the files to be updated as dictionary with the key being the path to the local file relative to your project root directory and the value being the corresponsing remote URL to check for updated file content. Then call this method with the files dictionary as parameter like so:
     
     ```swift
     let files = [
        "YourSourceDirectory/about.html": "https://www.example.com/about.html",
        "YourSourceDirectory/tos.html": "https://www.example.com/terms-of-service.html"
     ]
     
     BundleFileUpdater.updateBundleFilesFromCLI(files)
     ```
     
     To update your files on every build, go to your the _Build Phases_ tab for your project's target settings, add a _New Run Script Phase_ before the _Compile Sources_ phase and insert the follwing script where `"$SRCROOT/YourSourceDirectory/DownloadScript.swift"` is the new file you just created with the call to this method:
     
     ```sh
     cat "$PODS_ROOT/BundleFileUpdater/BundleFileUpdater/BundleFileUpdater.swift" "$SRCROOT/YourSourceDirectory/DownloadScript.swift" | xcrun -sdk macosx swift -
     ```
     
     - parameter files: the dictionary key is the path to the file in the app bundle relative to the project directory that should be updated if needed from the remote url string that is given as the corresponsing dictionary value. If the files' content have changed online and are not empty, the local files will be replaced by the downloaded remote files.
     - warning: Never call this method from app code as it calls `exit()`. It is designated to be called from a command line script.
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
