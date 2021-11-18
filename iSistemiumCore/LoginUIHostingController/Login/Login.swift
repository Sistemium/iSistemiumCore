//
//  Login.swift
//  iSistemiumCore
//
//  Created by Edgar Jan Vuicik on 2021-08-17.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI
import iPhoneNumberField
import Combine

struct Login: View {
    @State private var phoneNumber: String = ""
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
                    ZStack {
                        HStack (spacing: 0) {
                            Text("🇷🇺 +7")
                                    .frame(width: 90, height: 50)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundColor(.black)
                            TextField("(123) 456-78-90", text: $phoneNumber)
                                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                    .padding()
                                    .frame(width: 225, height: 50)
                                    .keyboardType(.phonePad)
                                    .introspectTextField { textField in
                                        textField.becomeFirstResponder()
                                    }
                                    .onReceive(Just(phoneNumber)) { number in
                                        if (number.count >= 10) {
                                            loading = true
                                            self.showPasswordView = true
                                            CoreAuthController.sendPhoneNumber(phoneNumber: "+7" + phoneNumber)
                                                    .done { (promise) in
                                                        loading = false
                                                    }
                                                    .catch { (error) in
                                                        alertText = (error as NSError).userInfo.first!.value as! String
                                                        showingAlert = true
                                                    }
                                        }
                                    }
                        }.padding()

                        RoundedRectangle(cornerRadius: 10).stroke()
                                .frame(width: 315, height: 50)
                    }
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
