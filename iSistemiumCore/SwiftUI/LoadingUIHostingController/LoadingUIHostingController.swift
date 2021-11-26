//
//  LoadingUIHostingController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-11-26.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

class LoadingUIHostingController: UIHostingController<Loading> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: Loading())
    }
}

