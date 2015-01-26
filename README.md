# InstrumentalKit
Objective-C and Swift code for use with the Instrumental logging service available at instrumentalapp.com.

# IKCollector
Swift implementation of a class used to send iOS app mobile analytics metrics to the Instrumental collector API at http://collector.instrumentalapp.com:8000/. Relies on CocoaAsyncSocket (https://github.com/robbiehanson/CocoaAsyncSocket) for the socket communication. You must add GCDAsyncSocket.h to your project's bridging header.
