//
//  Login.swift
//  iSistemiumCore
//
//  Created by Edgar Jan Vuicik on 2021-08-17.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI
import iPhoneNumberField

struct Login: View {
    @State var text: String = ""
    @State var isEditing: Bool = false

    var body: some View {
        iPhoneNumberField(nil, text: $text, isEditing: $isEditing)
            .flagHidden(false)
            .prefixHidden(false)
            .defaultRegion("RU")
            .font(UIFont(size: 30, weight: .light, design: .monospaced))
            .maximumDigits(10)
            .clearButtonMode(.whileEditing)
            .onClear { _ in isEditing.toggle() }
            .accentColor(Color.orange)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .gray, radius: 5)
            .padding()
            .scaleEffect(0.9)
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}
