//
//  Profile.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-10-25.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

extension Binding {
    func didSet(execute: @escaping (Value) -> Void) -> Binding {
        return Binding(
                get: { self.wrappedValue },
                set: {
                    self.wrappedValue = $0
                    execute($0)
                }
        )
    }
}

class ProfileDataObjc: NSObject {
    @objc
    static func setIsLocationAllowed(allowed: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ProfileData.shared.isLocationAllowed = allowed
        }
    }

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
            if (value >= 1.0) {
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
    @Published var nonloadedPictures: Int = 0
    @Published var unusedPictures: Int = STMGarbageCollector.sharedInstance.unusedImageFiles.count
    @Published var isLoading: Bool = false
    @Published var isLocationAllowed: Bool = false
    @Published var error: String? = nil
}

struct Profile: View {

    @State private var isPushAllowed = false
    @State private var showingLogoutAlert = false
    @State private var showingLocationPermissionsAlert = false
    @State private var showingNotificationPermissionsAlert = false
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
                if (profileData.isLoading) {
                    CircularProgressBar(value: $profileData.progressValue)
                            .frame(width: 175.0, height: 175.0)
                            .padding(.bottom, 20)
                            .padding(.trailing, 40)
                            .padding(.leading, 40)
                            .padding(.top, 40)
                    AnimatedText(text: NSLocalizedString("SYNCING DATA", comment: ""))
                    Spacer()
                }
                VStack {
                    Toggle("GEOLOCATION", isOn: $profileData.isLocationAllowed.didSet { (state) in
                        getLocationPermissions(activeActions: true)
                    })
                            .alert(isPresented: $showingLocationPermissionsAlert) {
                                Alert(title: Text("YOU NEED GO SETTING LOCATION"),
                                        message: Text("GO SETTINGS?"),
                                        primaryButton: .default(Text("SETTINGS"), action: {
                                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                        }),
                                        secondaryButton: .default(Text("CANCEL")))
                            }
                    Toggle("PUSH", isOn: $isPushAllowed.didSet { (state) in
                        getNotificationPermissions(activeActions: true)
                    })
                            .alert(isPresented: $showingNotificationPermissionsAlert) {
                                Alert(title: Text("YOU NEED GO SETTING NOTIFICATIONS"),
                                        message: Text("GO SETTINGS?"),
                                        primaryButton: .default(Text("SETTINGS"), action: {
                                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                        }),
                                        secondaryButton: .default(Text("CANCEL")))
                            }
                }
                        .padding(50)
                if (profileData.nonloadedPictures > 0 && !profileData.isLoading) {
                    let pluralString = STMFunctions.pluralType(forCount: UInt(profileData.nonloadedPictures))
                    let picturesCount = pluralString + "UPICTURES"
                    let detail = NSLocalizedString("WAITING FOR DOWNLOAD", comment: "")
                    let title = String(profileData.nonloadedPictures) + " " + NSLocalizedString(picturesCount, comment: "") + " " + detail
                    let download = NSLocalizedString("DOWNLOAD NOW", comment: "")
                    let stop = NSLocalizedString("DOWNLOAD STOP", comment: "")
                    Spacer()
                    Button(action: {
                        if (isDownloadingPictures) {
                            STMCorePicturesController.shared().downloadingPictures = false
                            isDownloadingPictures = false
                        } else {
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
                            Text(isDownloadingPictures ? stop : download)
                                    .font(.system(size: 16))
                        }
                                .padding()
                                .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                                .stroke(isDownloadingPictures ? Color.red : Color.blue, lineWidth: 3)
                                )
                    }
                            .accentColor(isDownloadingPictures ? Color.red : Color.blue)
                }
                if (profileData.unusedPictures > 0 && !profileData.isLoading) {
                    let pluralString = STMFunctions.pluralType(forCount: UInt(profileData.unusedPictures + 1))
                    let picturesCount = pluralString + "UPICTURES"
                    let unusedCount = pluralString + "UNUSED"
                    let title = String(profileData.unusedPictures) + " " + NSLocalizedString(unusedCount, comment: "") + " " + NSLocalizedString(picturesCount, comment: "")
                    Spacer()
                    Button(action: {
                        if (isFlushingPictures) {
                            STMGarbageCollector.sharedInstance.stopRemoveUnusedImages()
                            isFlushingPictures = false
                        } else {
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
                    }
                            .accentColor(isFlushingPictures ? Color.red : Color.blue)
                }
                Spacer()
                if profileData.error != nil && !STMCoreAuthController.shared().isDemo {
                    Text(profileData.error!)
                            .font(.title)
                            .foregroundColor(Color.red)
                }
                if (!profileData.isLoading && !STMCoreAuthController.shared().isDemo) {
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
                        showingLogoutAlert = true

                    }) {
                        Image(uiImage: STMFunctions.resize(UIImage(named: "exit-128.png")?.withTintColor(.blue), to: CGSize(width: 22, height: 22)))
                    }
                            .alert(isPresented: self.$showingLogoutAlert) {
                                Alert(title: Text("LOGOUT"), message: Text("R U SURE TO LOGOUT"),
                                        primaryButton: Alert.Button.destructive(
                                                Text("LOGOUT"), action: {
                                            STMCoreAuthController.shared().logout()
                                            STMCoreRootTBC.sharedRootVC().initAuthTab()
                                            showingLogoutAlert = false
                                            STMCoreAuthController.shared().initialLoadingCompleted = false
                                            (UIApplication.shared.delegate as! STMCoreAppDelegate).setupWindow()
                                        }
                                        ),
                                        secondaryButton: Alert.Button.cancel(
                                                Text("CANCEL"), action: {
                                            showingLogoutAlert = false
                                        }
                                        )
                                )
                            }
                    )
        }
                .onAppear{
                    onAppear()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    onAppear()
                }
    }

    func getNotificationPermissions(activeActions: Bool) {
        let current = UNUserNotificationCenter.current()

        current.getNotificationSettings(completionHandler: { (settings) in
            if settings.authorizationStatus == .notDetermined {
                if (activeActions) {
                    current.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
                        if error == nil && granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            self.isPushAllowed = true
                        } else {
                            self.isPushAllowed = false
                        }
                    }
                }
            } else if settings.authorizationStatus == .denied {
                if (activeActions) {
                    showingNotificationPermissionsAlert = true
                }
                self.isPushAllowed = false
            } else if settings.authorizationStatus == .authorized {
                if (activeActions) {
                    showingNotificationPermissionsAlert = true
                }
                self.isPushAllowed = true
            }
        })
    }

    func getLocationPermissions(activeActions: Bool) {
        let locationTracker = (STMCoreSessionManager.shared().currentSession as? STMCoreSession)?.locationTracker
        locationTracker?.checkStatus()
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                if (activeActions) {
                    let locationManager = CLLocationManager()
                    locationManager.requestAlwaysAuthorization()
                }
                break;
            case .restricted:
                if (activeActions) {
                    showingLocationPermissionsAlert = true
                }
                profileData.isLocationAllowed = false
                break;
            case .denied:
                if (activeActions) {
                    showingLocationPermissionsAlert = true
                }
                profileData.isLocationAllowed = false
                break;
            case .authorizedAlways:
                if (activeActions) {
                    showingLocationPermissionsAlert = true
                }
                profileData.isLocationAllowed = true
                break;
            case .authorizedWhenInUse:
                if (activeActions) {
                    showingLocationPermissionsAlert = true
                }
                profileData.isLocationAllowed = true
                break;
            @unknown default:
                if (activeActions) {
                    showingLocationPermissionsAlert = true
                }
                profileData.isLocationAllowed = false
                break;
            }
        } else {
            profileData.isLocationAllowed = false
        }
    }

    func onAppear(){
        if (!STMCoreAuthController.shared().isDemo) {
            ProfileData.shared.nonloadedPictures = Int(STMCorePicturesController.shared().nonloadedPicturesCount)
        } else {
            ProfileData.shared.nonloadedPictures = 0
        }

        getNotificationPermissions(activeActions: false)

        getLocationPermissions(activeActions: false)
    }

}
