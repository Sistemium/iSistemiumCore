//
//  STMSwiftConstants.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 15/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import Foundation

struct STMSwiftConstants {

    static let SYSTEM_VERSION = NSString(string: UIDevice.currentDevice().systemVersion).floatValue
    static let LIMIT_COUNT = 4
    static let IMAGE_PADDING : CGFloat = 6
    static let CELL_IMAGES_SIZE:CGFloat = 54.0
    static let ACTIVE_BLUE_COLOR = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    static let STM_SUPERLIGHT_BLUE_COLOR = UIColor(red:0.92, green:0.96, blue:1, alpha:1)
    static let STM_LIGHT_LIGHT_GREY_COLOR = UIColor(red:0.9, green:0.9, blue:0.9, alpha:1)
    
    struct ScriptMessageNames {

        static let WK_SCRIPT_MESSAGE_FIND: String = "find"
        static let WK_SCRIPT_MESSAGE_FIND_ALL: String = "findAll"

    }
    
}