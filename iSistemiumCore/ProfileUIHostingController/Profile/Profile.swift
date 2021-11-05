//
//  Profile.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-10-25.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

class ProfileDataObjc: NSObject {
    @objc
    static func setProgress(value: Float) {
        ProfileData.shared.progressValue = value
    }
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var progressValue: Float = 0.5
}

struct Profile: View {

    @State private var showingAlert = false
    @ObservedObject var profileData: ProfileData = ProfileData.shared

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 100)
                Text(STMCoreAuthController.shared().userName)
                Text(STMCoreAuthController.shared().phoneNumber)
                ProgressBar(value: $profileData.progressValue).frame(height: 20).padding()
                Spacer()
            }
                    .navigationBarTitle("\(STMCoreSessionManager.shared()?.currentSession?.currentAppVersion ?? "")", displayMode: .inline)
                    .navigationBarItems(leading:
                    Button(action: {
                        showingAlert = true

                    }) {
                        Image(uiImage: STMFunctions.resize(UIImage(named: "exit-128.png")?.withTintColor(.blue), to: CGSize(width: 22, height: 22)))
                    }.alert(isPresented: self.$showingAlert) {
                        Alert(title: Text("LOGOUT"), message: Text("R U SURE TO LOGOUT"),
                                primaryButton: Alert.Button.destructive(
                                        Text("LOGOUT"), action: {
                                    STMCoreAuthController.shared().logout()
                                    showingAlert = false
                                }
                                ),
                                secondaryButton: Alert.Button.cancel(
                                        Text("CANCEL"), action: {
                                    showingAlert = false
                                }
                                )
                        )
                    }
                    )
        }
    }
}

struct ProgressBar: View {
    @Binding var value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.3)
                        .foregroundColor(Color(UIColor.systemTeal))

                Rectangle().frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                        .foregroundColor(Color(UIColor.systemBlue))
                        .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
}
