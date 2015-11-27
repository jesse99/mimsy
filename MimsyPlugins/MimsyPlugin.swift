//
//  MimsyPlugin.swift
//  Mimsy
//
//  Created by Jesse Jones on 11/26/15.
//  Copyright © 2015 Jesse Jones. All rights reserved.
//

import Cocoa

public class MimsyPlugin: NSObject {
    public func loading() {NSLog("loading swift")}
    
    public func unloading() {NSLog("unloading swift!")}
}

public func LOG(topic: String, format: String, args: CVarArgType...)
{
    let text = String(format: format, arguments: args)
    
    let app = NSApp.delegate
    app?.performSelector("pluginLog:text:", withObject: topic, withObject: text)
}
