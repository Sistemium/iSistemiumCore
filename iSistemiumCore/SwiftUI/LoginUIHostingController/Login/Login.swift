//
//  Login.swift
//  iSistemiumCore
//
//  Created by Edgar Jan Vuicik on 2021-08-17.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI
import Combine

//for some reason I cannot make responder a property of swiftUI and modify it from introspect
class Responder {
    static var responder: UIResponder?
}

struct Login: View {
    @State private var phoneNumber: String = ""
    @State private var showPasswordView = false
    @State private var loading = false
    @State private var loading2 = true
    @State private var alertText = ""
    @State private var showingAlert = false
    @State private var wrongSMSCount = 0

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
                            .navigationBarBackButtonHidden(true)
                            .navigationBarItems(leading: Button(action: {
                                showPasswordView = false
                                Responder.responder?.becomeFirstResponder()
                                STMCoreAuthController.shared().controllerState = STMAuthState.enterPhoneNumber
                            }) {
                                Image(systemName: "arrow.left")
                            })
                            , isActive: self.$showPasswordView) {
                        EmptyView()
                    }
                    Spacer().frame(height: 150)
                    ZStack {
                        HStack(spacing: 0) {
                            Text("🇷🇺 +7")
                                    .frame(width: 90, height: 50)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundColor(.black)
                            TextField("(123) 456-78-90", text: $phoneNumber)
                                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                    .padding()
                                    .frame(width: 250, height: 50)
                                    .keyboardType(.numberPad)
                                    .introspectTextField { textField in
                                        Responder.responder = textField
                                        textField.becomeFirstResponder()
                                    }
                                    .onReceive(Just(phoneNumber)) { _number in
                                        let number = _number.filter { "0123456789".contains($0) }
                                        //showPasswordView check fixes weird bug with onReceive called twice
                                        if (number.count >= 10 && !showPasswordView) {
                                            self.showPasswordView = true
                                            loading = true
                                            CoreAuthController.sendPhoneNumber(phoneNumber: "+7" + number)
                                                    .done { (promise) in
                                                        loading = false
                                                    }
                                                    .catch { (error) in
                                                        alertText = (error as NSError).userInfo.first!.value as! String
                                                        showingAlert = true
                                                    }
                                            phoneNumber = ""
                                        }
                                    }
                        }
                                .padding()

                        RoundedRectangle(cornerRadius: 10).stroke()
                                .frame(width: 340, height: 50)
                    }
                    VStack {
                        Text("POLICY_DESC1")
                        Text("POLICY_DESC2")
                        Button(NSLocalizedString("POLICY", comment: "")) {
                            if let url = URL(string: NSLocalizedString("POLICY_URL", comment: "")) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Spacer()
                }
                        .alert(isPresented: self.$showingAlert) {
                            Alert(title: Text(alertText),
                                    dismissButton: Alert.Button.default(
                                            Text("OK"), action: {
                                        if (alertText == NSLocalizedString("WRONG PHONE NUMBER", comment: "") || wrongSMSCount >= 2) {
                                            showPasswordView = false
                                            wrongSMSCount = 0
                                        } else {
                                            wrongSMSCount += 1
                                        }
                                        loading = false
                                    })
                            )
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
                    .navigationViewStyle(StackNavigationViewStyle())
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
