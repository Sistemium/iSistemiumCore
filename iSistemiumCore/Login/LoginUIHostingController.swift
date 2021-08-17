//
//  LoginUIHostingController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-08-17.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

class LoginUIHostingController: UIHostingController<Login> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: Login())
    }
}
