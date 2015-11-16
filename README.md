# BundleFileUpdater

[![Version](https://img.shields.io/cocoapods/v/BundleFileUpdater.svg?style=flat)](http://cocoapods.org/pods/BundleFileUpdater)
[![License](https://img.shields.io/cocoapods/l/BundleFileUpdater.svg?style=flat)](http://cocoapods.org/pods/BundleFileUpdater)
[![Platform](https://img.shields.io/cocoapods/p/BundleFileUpdater.svg?style=flat)](http://cocoapods.org/pods/BundleFileUpdater)

Deliver your app with up-to-date local resource files in your app bundle and update them dynamically from a remote url both with every build and dynamically at runtime. Your users will always have the latest resource files' version without the need for a new app submission.

## Usage

### Update file at runtime

Keep a local file in the app bundle up-to-date from two sources: from the app bundle and from a remote URL. Therefore an updatable copy of this file is automatically copied from the app bundle to the document directory which should be the single source of truth in your application. No need to reference the file from app bundle or the remote URL directly anywhere else except for the `BundleFileUpdater.updateFile` call. The method supports a simple, automatic and optional string search and replace before updating the file from either source:

```swift
let localFileURL = BundleFileUpdater.updateFile("about.html", url: "https://www.example.com/about.html", replacingTexts: ["href=\"/terms-of-service.html\"": "href=\"tos.html\""], didReplaceFile: { (destinationURL, error) in
    guard error == nil else {
       // an error occured or the remote file had no changes …
       return
    }
    // local file was updated from url or from app bundle (because of an app update) …
})
```

Get the file url for an updatable file that is managed by this class which is stored in the document directory:

```swift
let localFileURL = BundleFileUpdater.urlForFile("about.html")
```

### Update files with every build

To do so, you should add a new file to your project (but not to any of your targets) where you specify the files to be updated as dictionary with the key being the path to the local file relative to your project root directory and the value being the corresponsing remote URL to check for updated file content. Then call this method with the files dictionary as parameter like so:

```swift
let files = [
   "YourSourceDirectory/about.html": "https://www.example.com/about.html",
   "YourSourceDirectory/tos.html": "https://www.example.com/terms-of-service.html"
]
BundleFileUpdater.updateBundleFilesFromCLI(files)
```

To update your files on every build, go to your the _Build Phases_ tab for your project's target settings, add a _New Run Script Phase_ before the _Compile Sources_ phase and insert the follwing script where `"$SRCROOT/YourSourceDirectory/DownloadScript.swift"` is the new file you just created with the call to `BundleFileUpdater.updateBundleFilesFromCLI`:

```sh
cat "$PODS_ROOT/BundleFileUpdater/BundleFileUpdater/BundleFileUpdater.swift" "$SRCROOT/YourSourceDirectory/DownloadScript.swift" | swift -
```

## Installation

BundleFileUpdater is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "BundleFileUpdater"
```

## License

BundleFileUpdater is available under the MIT license. See the LICENSE file for more info.
