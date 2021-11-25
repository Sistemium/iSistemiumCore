//
//  ☯ ProfileUIHostingController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-10-25.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

class ProfileUIHostingController: UIHostingController<Profile> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: Profile())
    }
}
