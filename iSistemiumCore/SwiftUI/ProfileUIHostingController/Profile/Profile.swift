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
            if (value == 1.0){
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ProfileData.shared.isLoading = false
                }
            } else {
                ProfileData.shared.isLoading = true
            }
        }
    }
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var progressValue: Float = 0
    @Published var isLoading: Bool = false
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
                if(profileData.isLoading){
                    CircularProgressBar(value: $profileData.progressValue)
                            .frame(width: 150.0, height: 150.0)
                            .padding(.bottom, 20)
                            .padding(.trailing, 40)
                            .padding(.leading, 40)
                            .padding(.top, 40)
                    AnimatedText(text: "SYNCING DATA".localizedCapitalized)
                    Spacer()
                } else {
                    Spacer()
                    Button(action: {
                        STMCoreSessionManager.shared()?.currentSession.syncer.receiveData()
                        if (STMCoreAuthController.shared().userName.contains("DEMO") && STMCoreSessionManager.shared()?.currentSession != nil){
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                ProfileDataObjc.setProgress(value: 0.1)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                ProfileDataObjc.setProgress(value: 0.9)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                ProfileDataObjc.setProgress(value: 1.0)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title)
                            Text("SYNC DATA")
                                    .fontWeight(.semibold)
                                    .font(.headline)
                        }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .padding(.horizontal, 20)
                    }
                    Spacer().frame(height: 30)
                }
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
                                    STMCoreRootTBC.sharedRootVC().initAuthTab()
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
        }.onAppear {
            if (STMCoreAuthController.shared().userName.contains("DEMO") && STMCoreSessionManager.shared()?.currentSession != nil){
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ProfileDataObjc.setProgress(value: 0.1)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    ProfileDataObjc.setProgress(value: 0.9)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    ProfileDataObjc.setProgress(value: 1.0)
                }
            }
        }
    }
}
