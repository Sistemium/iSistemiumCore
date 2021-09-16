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
    @State private var showLoadingView = false


    var body: some View {
        NavigationView{
            VStack{
                //https://developer.apple.com/forums/thread/677333
                NavigationLink(destination: EmptyView()) {
                    EmptyView()
                }

                NavigationLink(destination:
                                ActivityIndicator()
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                               , isActive: self.$showLoadingView) { EmptyView() }
                NavigationLink(destination:
                                PasswordView { SMSCode in
                                    CoreAuthController.sendSMSCode(SMSCode: SMSCode).done {
                                        self.showPasswordView = false
                                        self.showLoadingView = true
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
                Button("Send") {
                    CoreAuthController.sendPhoneNumber(phoneNumber: text).done {
                        self.showPasswordView = true
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

struct ActivityIndicator: View {

  @State private var isAnimating: Bool = false

  var body: some View {
    GeometryReader { (geometry: GeometryProxy) in
      ForEach(0..<5) { index in
        Group {
          Circle()
            .frame(width: geometry.size.width / 5, height: geometry.size.height / 5)
            .scaleEffect(!self.isAnimating ? 1 - CGFloat(index) / 5 : 0.2 + CGFloat(index) / 5)
            .offset(y: geometry.size.width / 10 - geometry.size.height / 2)
          }.frame(width: geometry.size.width, height: geometry.size.height)
            .rotationEffect(!self.isAnimating ? .degrees(0) : .degrees(360))
            .animation(Animation
              .timingCurve(0.5, 0.15 + Double(index) / 5, 0.25, 1, duration: 1.5)
              .repeatForever(autoreverses: false))
        }
      }
    .aspectRatio(1, contentMode: .fit)
    .onAppear {
        self.isAnimating = true
    }
  }
}
