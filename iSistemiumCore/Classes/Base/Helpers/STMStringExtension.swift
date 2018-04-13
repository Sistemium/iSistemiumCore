//
//  STMStringExtension.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 04/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

extension String {
    var first: String {
        return String(prefix(1))
    }
    var last: String {
        return String(suffix(1))
    }
    var uppercaseFirst: String {
        return first.uppercased() + String(dropFirst())
    }
    var dropLast: String {
        return String(dropLast())
    }
}
