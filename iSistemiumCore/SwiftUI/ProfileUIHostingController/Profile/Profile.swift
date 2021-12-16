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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ProfileData.shared.isLoading = true;
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                ProfileData.shared.error = nil
            }
            withAnimation(Animation.linear(duration: 0.1)) {
                ProfileData.shared.progressValue = value
            }
            if (value >= 1.0){
                ProfileData.shared.isLoading = false;
                ProfileData.shared.progressValue = 0
            }
        }
    }

    @objc
    static func setError(error: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                ProfileData.shared.error = error
            }
        }
    }
    
    @objc
    static func setUnloadedPhotos(value: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ProfileData.shared.nonloadedPictures = value
        }
    }
    
    @objc
    static func setUnusedPhotos(value: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ProfileData.shared.unusedPictures = value
        }
    }
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var progressValue: Float = 0
    @Published var nonloadedPictures: Int = Int(STMCorePicturesController.shared().nonloadedPicturesCount)
    @Published var unusedPictures: Int = STMGarbageCollector.sharedInstance.unusedImageFiles.count
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
}

struct Profile: View {

    @State private var showingAlert = false
    @ObservedObject var profileData: ProfileData = ProfileData.shared
    @State private var isDownloadingPictures: Bool = false
    @State private var isFlushingPictures: Bool = false

    var repeatingTextAnimation: Animation {
        Animation
                .linear(duration: 1)
                .repeatForever()
    }

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 100)
                Text(STMCoreAuthController.shared().userName).font(.headline)
                if(profileData.isLoading){
                    CircularProgressBar(value: $profileData.progressValue)
                            .frame(width: 175.0, height: 175.0)
                            .padding(.bottom, 20)
                            .padding(.trailing, 40)
                            .padding(.leading, 40)
                            .padding(.top, 40)
                    AnimatedText(text: NSLocalizedString("SYNCING DATA", comment: ""))
                    Spacer()
                }
                if (profileData.nonloadedPictures > 0 && !profileData.isLoading){
                    let pluralString = STMFunctions.pluralType(forCount: UInt(profileData.nonloadedPictures))
                    let picturesCount = pluralString + "UPICTURES"
                    let title = String(profileData.nonloadedPictures) + " " + NSLocalizedString(picturesCount, comment: "")
                    let detail = NSLocalizedString("WAITING FOR DOWNLOAD", comment: "")
                    Spacer()
                    Button(action: {
                        if (isDownloadingPictures){
                            STMCorePicturesController.shared().downloadingPictures = false
                            isDownloadingPictures = false
                        }else {
                            STMCorePicturesController.shared().checkPhotos()
                            STMCorePicturesController.shared().downloadingPictures = true
                            isDownloadingPictures = true
                        }
                    }) {
                        VStack {
                            Image(systemName: "photo")
                                    .font(.title)
                            Spacer().frame(height: 3)
                            Text(title)
                                .font(.system(size: 16))
                            Text(detail)
                                .font(.system(size: 14))
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isDownloadingPictures ? Color.red : Color.blue, lineWidth: 3)
                        )
                    }.accentColor(isDownloadingPictures ? Color.red : Color.blue)
                }
                if (profileData.unusedPictures > 0 && !profileData.isLoading){
                    let pluralString = STMFunctions.pluralType(forCount: UInt(profileData.unusedPictures + 1))
                    let picturesCount = pluralString + "UPICTURES"
                    let unusedCount = pluralString + "UNUSED"
                    let title = String(profileData.unusedPictures) +  " " + NSLocalizedString(unusedCount, comment: "") + " " + NSLocalizedString(picturesCount, comment: "")
                    Spacer()
                    Button(action: {
                        if (isFlushingPictures){
                            STMGarbageCollector.sharedInstance.stopRemoveUnusedImages()
                            isFlushingPictures = false
                        }else {
                            STMGarbageCollector.sharedInstance.removeUnusedImages()
                            isFlushingPictures = true
                        }
                    }) {
                        VStack {
                            Image(systemName: "photo")
                                    .font(.title)
                            Spacer().frame(height: 3)
                            Text(title)
                                .font(.system(size: 16))
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isFlushingPictures ? Color.red : Color.blue, lineWidth: 3)
                        )
                    }.accentColor(isFlushingPictures ? Color.red : Color.blue)
                }
                Spacer()
                if profileData.error != nil {
                    Text(profileData.error!)
                            .font(.title)
                            .foregroundColor(Color.red)
                }
                if(!profileData.isLoading && !STMCoreAuthController.shared().userName.contains("DEMO")){
                    Button(action: {
                        STMCoreSessionManager.shared()?.currentSession.syncer.receiveData()
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
                                    STMCoreAuthController.shared().initialLoadingCompleted = false
                                    (UIApplication.shared.delegate as! STMCoreAppDelegate).setupWindow()
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
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
