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
    @State private var loading = false
    @State private var showingAlert = false

    var body: some View {
        NavigationView{
            VStack{
                //https://developer.apple.com/forums/thread/677333
                NavigationLink(destination: EmptyView()) {
                    EmptyView()
                }
                NavigationLink(destination:
                                VStack{
                    if (loading){
                            ActivityIndicator(isAnimating: $loading, style: .large)
                    } else {
                        PasswordView { SMSCode in
                            self.loading = true
                            CoreAuthController.sendSMSCode(SMSCode: SMSCode).done {
                            }
                        }
                    }
                }
                               , isActive: self.$showPasswordView) { EmptyView() }
                Spacer().frame(height: 50)
                iPhoneNumberField(nil, text: self.$text, isEditing: $isEditing)
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
                Button("SEND") {
                    loading = true
                    self.showPasswordView = true
                    CoreAuthController.sendPhoneNumber(phoneNumber: text)
                        .done { (promise) in
                            loading = false
                        }
                        .catch { (error) in
                            showPasswordView = false
                            loading = false
                            showingAlert = true
                        }
                }.alert(isPresented: self.$showingAlert) {
                    Alert(title: Text("WRONG PHONE NUMBER"))
                }
                Spacer()
            }
            .navigationBarTitle("ENTER TO SISTEMIUM", displayMode: .inline)
        }
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}

struct ActivityIndicator: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
