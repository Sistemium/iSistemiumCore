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
        DispatchQueue.main.async {
            ProfileData.shared.progressValue = value
        }
    }
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var progressValue: Float = 0
}

struct Profile: View {

    @State private var showingAlert = false
    @ObservedObject var profileData: ProfileData = ProfileData.shared
    
    var repeatingTextAnimation: Animation {
        Animation
                .linear(duration: 1)
                .repeatForever()
    }

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 100)
                Text(STMCoreAuthController.shared().userName)
                Text(STMCoreAuthController.shared().phoneNumber)
                CircularProgressBar(value: $profileData.progressValue)
                        .frame(width: 150.0, height: 150.0)
                        .padding(40.0)
                SyncingData()
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

//

struct SyncingData: View {
    @State private var text = "SYNCING DATA".localizedCapitalized
    @State private var index = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(text)
                .frame(minWidth: 120, alignment: .leading)
                .onReceive(timer) { _ in
                    if index < 3 {
                        text += "."
                        index += 1
                    } else {
                        text = "SYNCING DATA".localizedCapitalized
                        index = 0
                    }
                }
    }
}

struct CircularProgressBar: View {
    @Binding var value: Float

    var body: some View {
        ZStack {
            Circle()
                    .stroke(lineWidth: 10.0)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)

            Circle()
                    .trim(from: 0.0, to: CGFloat(min(value, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .opacity(0.6)
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear)

            Text(String(format: "%.0f %%", min(value, 1.0) * 100.0))
                    .font(.largeTitle)
        }
    }
}
