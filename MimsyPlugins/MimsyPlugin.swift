//
//  MimsyPlugin.swift
//  Mimsy
//
//  Created by Jesse Jones on 11/26/15.
//  Copyright © 2015 Jesse Jones. All rights reserved.
//

import Cocoa

public class MimsyPlugin: NSObject {
    public func loading() {NSLog("loading swift!")}
    
    public func unloading() {NSLog("unloading swift")}
}
