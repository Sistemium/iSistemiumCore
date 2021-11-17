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
    @State private var text: String = "+7"
    @State private var showPasswordView = false
    @State private var loading = false
    @State private var loading2 = true
    @State private var alertText = ""
    @State private var showingAlert = false

    var body: some View {
        if (loading2) {
            ActivityIndicator(isAnimating: $loading2, style: .large).onAppear {
                if (STMCoreAuthController.shared().controllerState == STMAuthState.enterPhoneNumber) {
                    self.loading2 = false
                } else {
                    CoreAuthController.checkPhoneNumber().done {
                        self.loading2 = false
                    }
                }

            }
        } else {
            NavigationView {
                VStack {
                    //https://developer.apple.com/forums/thread/677333
                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }
                    NavigationLink(destination:
                    VStack {
                        if (loading) {
                            ActivityIndicator(isAnimating: $loading, style: .large)
                        } else {
                            PasswordView { SMSCode in
                                self.loading = true
                                CoreAuthController.sendSMSCode(SMSCode: SMSCode).done {
                                        }
                                        .catch { (error) in
                                            alertText = (error as NSError).userInfo.first!.value as! String
                                            loading = false
                                            showingAlert = true
                                        }
                            }
                        }
                    }
                            , isActive: self.$showPasswordView) {
                        EmptyView()
                    }
                    Spacer().frame(height: 50)
                    PhoneNumberInput(countryCode: "7", countryFlag: "🇷🇺")
                    Spacer()
                }.alert(isPresented: self.$showingAlert) {
                    Alert(title: Text(alertText),
                            dismissButton: Alert.Button.default(
                                    Text("OK"), action: {
                                showPasswordView = false
                                loading = false

                            }
                            )
                    )
                }
            }.onAppear {
                        STMCoreAuthController.shared().logout()
                    }
                    .navigationBarTitle("ENTER TO SISTEMIUM", displayMode: .inline)
                    .navigationBarItems(trailing:
                    Button(action: {
                        loading = true
                        showPasswordView = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            CoreAuthController.demoAuth()
                        }
                    }) {
                        Text("DEMO")
                    }
                    )
        }
    }
}


struct ActivityIndicator: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
