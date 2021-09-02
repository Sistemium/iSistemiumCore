//
//  Login.swift
//  iSistemiumCore
//
//  Created by Edgar Jan Vuicik on 2021-08-17.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI
import iPhoneNumberField
import Introspect

struct Login: View {
    @State private var text: String = ""
    @State private var isEditing: Bool = false
    @State private var showPasswordView = false
    @State private var requestID:String? = nil


    var body: some View {
        NavigationView{
            VStack{
                NavigationLink(destination:
                                PasswordView { SMSCode in
                                    CoreAuthController.sendSMSCode(requestID: requestID!, SMSCode: SMSCode).done {
                                        print("______________")
                                    }
                                }
                    , isActive: $showPasswordView) { EmptyView() }
                Spacer().frame(height: 50)
                iPhoneNumberField(nil, text: $text, isEditing: $isEditing)
                    .flagHidden(false)
                    .prefixHidden(false)
                    .defaultRegion("RU")
                    .font(UIFont(size: 30, weight: .light, design: .monospaced))
                    .clearButtonMode(.whileEditing)
                    .onClear { _ in isEditing.toggle() }
                    .accentColor(Color.orange)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: .gray, radius: 5)
                    .padding()
                    .scaleEffect(0.9)
                    .introspectTextField { textField in
                        textField.becomeFirstResponder()
                    }
                Button("Send") {
                    CoreAuthController.sendPhoneNumber(phoneNumber: text).done { data in
                        requestID = data
                        showPasswordView = true
                    }
                }
                Spacer()
            }
            .navigationBarTitle("Navigation", displayMode: .inline)
        }
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}
