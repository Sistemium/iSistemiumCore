//
// Created by Edgar Jan Vuicik on 2021-11-12.
// Copyright (c) 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

struct PhoneNumberInput: View {

    var body: some View {
        HStack {
            Text("+370")
                .font(.system(size: 20))
                .foregroundColor(.gray)
            TextField("Phone number", text: .constant(""))
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
    }
}