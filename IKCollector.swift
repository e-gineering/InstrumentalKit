//
//  IKCollector.swift
//  InstrumentalKit
//
//  Created by Chris Patterson on 1/22/15.
//  Copyright (c) 2015 E-gineering, LLC. All rights reserved.
//

import Foundation
import UIKit

public class IKCollector : NSObject, GCDAsyncSocketDelegate
{
    enum MessageTag: Int
    {
        case Hello = 0
        case Auth
        case Increment
        case Gauge
        
        static func responseExpectedForTag(tag:Int) -> Bool
        {
            return (tag == Hello.rawValue || tag == Auth.rawValue)
        }
        
        func responseExpected() -> Bool
        {
            return MessageTag.responseExpectedForTag(self.rawValue)
        }
        
        func name() -> String
        {
            switch (self)
            {
                case .Hello:
                    return "hello"
                case .Auth:
                    return "authenticate"
                case .Increment:
                    return "increment"
                case .Gauge:
                    return "gauge"
            }
        }
    }

    // Constants for the Instrumental collector hostname and port number
    let kCollectorHostname: String = "collector.instrumentalapp.com"
    let kCollectorPort    : UInt16 = 8000
    
    // The dispatch queue on which all socket delegate callbacks will occur
    var queue             : dispatch_queue_t?
    
    // The GCDAsyncSocket object used for server communications
    var socket            : GCDAsyncSocket?
    
    // Intrumental API key assigned to your project
    var apiKey            : String
    
    // optional prefix shared by all metrics collected by this instance
    var metricsBase       : String?
    
    // flag to mark once we've been authenticated; metrics calls are batched up until this is set
    var isAuthenticated   : Bool = false
    
    var waitingMetrics    : Array<(String,MessageTag)>
    
    // MARK: initializers
    
    init(apiKey:String, metricsBase:String? = nil)
    {
        self.apiKey         = apiKey
        self.metricsBase    = metricsBase
        self.queue          = dispatch_queue_create("com.e-gineering.InstrumentalKit.delegateQ", DISPATCH_QUEUE_SERIAL);
        self.waitingMetrics = []
        
        super.init()
        
        if let error = self.connect()
        {
            NSLog("IKCollector: Error connecting to '%@': %@", kCollectorHostname, error);
        }
    }
    
    // MARK: private methods
    
    private func write(message:String, tag:MessageTag)
    {
        if (self.connect() != nil)
        {
            return;
        }
        let data = message.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
        self.socket!.writeData(data, withTimeout: -1, tag: tag.rawValue);
        NSLog("IKCollector wrote '%@'", message.stringByReplacingOccurrencesOfString("\n", withString:""))
    }
    
    private func catchUp()
    {
        if (self.waitingMetrics.count > 0)
        {
            for metric in self.waitingMetrics
            {
                self.write(metric.0, tag: metric.1)
            }
            self.waitingMetrics = []
        }
    }
    
    private func writeMetric(message:String, tag:MessageTag)
    {
        if (!self.isAuthenticated)
        {
            self.waitingMetrics.append((message,tag))
            return
        }
        
        self.catchUp()
        self.write(message, tag: tag)
    }
    
    private func fullMetricName(metricName:String) -> String
    {
        var fullName = metricName
        if let baseName = self.metricsBase
        {
            fullName = baseName + "." + metricName
        }
        return fullName
    }
    
    private func hello()
    {
        let platformName    = UIDevice.currentDevice().systemName.stringByReplacingOccurrencesOfString(" ", withString: "-")
        let platformVersion = UIDevice.currentDevice().systemVersion
        let hostName        = UIDevice.currentDevice().identifierForVendor.UUIDString
        let command         = MessageTag.Hello.name()
        let helloString     = "\(command) version InstrumentalKit/0.1 platform \(platformName)/\(platformVersion) hostname \(hostName)\n"
        self.write(helloString, tag:.Hello)
    }
    
    private func authenticate()
    {
        let command    = MessageTag.Auth.name()
        let authString = "\(command) \(self.apiKey)\n"
        self.write(authString, tag:.Auth)
    }
    
    // MARK: public methods
    
    func connect() -> NSError?
    {
        var error: NSError? = nil
        
        if (self.socket == nil)
        {
            self.socket = GCDAsyncSocket(delegate: self, delegateQueue: self.queue);
            if (self.socket == nil)
            {
                error = NSError(domain  : "com.e-gineering.InstrumentalKit",
                                code    : -1,
                                userInfo: [NSLocalizedDescriptionKey: "Could not create socket"])
                return error
            }
        }
        
        if (!self.socket!.isConnected)
        {
            self.socket!.connectToHost(kCollectorHostname, onPort: kCollectorPort, error: &error)
        }
        
        return error
    }
    
    func disconnect()
    {
        self.catchUp()
        self.socket?.disconnectAfterWriting()
    }
    
    func increment(metricName:String, by amount:Int = 1)
    {
        let timestamp = NSDate().timeIntervalSince1970
        let command   = MessageTag.Increment.name()
        let string = "\(command) \(self.fullMetricName(metricName)) \(amount) \(timestamp)\n"
        self.writeMetric(string, tag:.Increment)
    }
    
    func gauge(metricName:String, value:Double = 0.0, absolute:Bool = false)
    {
        let timestamp = NSDate().timeIntervalSince1970
        var command = MessageTag.Gauge.name()
        if (absolute)
        {
            command = "\(command)_absolute"
        }
        let string = "\(command) \(self.fullMetricName(metricName)) \(value) \(timestamp)\n"
        self.writeMetric(string, tag:.Gauge)
    }
    
    // MARK: GCDAsyncSocketDelegate methods
    
    public func socket(sock:GCDAsyncSocket!, didConnectToHost host:String!, port:UInt16)
    {
        NSLog("IKCollector connected")
        
        self.hello()
    }
    
    public func socket(sock:GCDAsyncSocket!, didWriteDataWithTag tag:Int)
    {
        if let messageTag = MessageTag(rawValue: tag)
        {
            //NSLog("socket didWriteDataWithTag: %@", messageTag.name())
            
            if (messageTag.responseExpected())
            {
                sock?.readDataWithTimeout(3.0, tag: tag);
            }
        }
    }
    
    public func socket(sock:GCDAsyncSocket!, didReadData data:NSData!, withTag tag:Int)
    {
        if let response = NSString(data: data, encoding: NSASCIIStringEncoding)
        {
            NSLog("IKCollector read '%@'", response.stringByReplacingOccurrencesOfString("\n", withString: ""))
            
            if (response.isEqualToString("ok\n"))
            {
                if let messageTag = MessageTag(rawValue: tag)
                {
                    if (messageTag == .Hello)
                    {
                        self.authenticate()
                    }
                    else if (messageTag == .Auth)
                    {
                        self.isAuthenticated = true;
                        self.catchUp()
                    }
                }
            }
        }
    }
    
    public func socketDidDisconnect(sock:GCDAsyncSocket!, withError error:NSError!)
    {
        NSLog("IKCollector disconnected with error: %@", error);
        self.socket = nil
        self.isAuthenticated = false
    }
}
