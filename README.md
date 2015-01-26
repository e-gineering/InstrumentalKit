# InstrumentalKit
Objective-C and Swift code for use with the Instrumental logging service ([instrumentalapp.com](http://instrumentalapp.com)). 

## IKCollector
Swift implementation of a class used to send iOS app mobile analytics metrics to the [Instrumental collector API](https://instrumentalapp.com/docs/collector%2Freadme). Relies on [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) for the socket communication. 

You must add GCDAsyncSocket.h to your project's [bridging header](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html#//apple_ref/doc/uid/TP40014216-CH10-XID_79).

## To Do:
* Add support for the full [Instrumental agent API](https://instrumentalapp.com/docs).
* Make this a complete framework bundle.
* Add a CocoaPods podspec once CocoaPods supports Swift or mixed-language frameworks.

