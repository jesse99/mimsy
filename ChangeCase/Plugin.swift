//
//  Plugin.swift
//  Mimsy
//
//  Created by Jesse Jones on 11/26/15.
//  Copyright © 2015 Jesse Jones. All rights reserved.
//

import Cocoa
import MimsyPlugins

class ChangeCase: MimsyPlugin {
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            log("App", format: "loading change case (stage 1)")
        }
        
        return nil
    }
}
