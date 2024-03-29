//
//  Loading.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-11-26.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

class LoadingDataObjc: NSObject {
    @objc
    static func finishLoading(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if (LoadingData.shared.progressValue >= 0.98){
                STMCoreAuthController.shared().initialLoadingCompleted = true
                (UIApplication.shared.delegate as! STMCoreAppDelegate).setupWindow()
                LoadingData.shared.progressValue = 0
            }
        }
    }
    @objc
    static func setProgress(value: Float) {
        let _value = value * 0.98
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                LoadingData.shared.error = nil
            }
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                LoadingData.shared.warning = nil
            }
            withAnimation(Animation.linear(duration: 0.1)) {
                LoadingData.shared.progressValue = _value
            }
        }
        if(STMCoreAuthController.shared().isDemo || _value >= 1.0){
            finishLoading()
        }
    }
    @objc
    static func setError(error:String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                LoadingData.shared.error = error
            }
        }
    }
    
    @objc
    static func setWarning(warning: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                LoadingData.shared.warning = warning
            }
        }
    }
}

class LoadingData: ObservableObject {
    static let shared = LoadingData()
    @Published var progressValue: Float = 0
    @Published var error: String? = nil
    @Published var warning: String? = nil
}

struct Loading: View{

    @ObservedObject var loadingData: LoadingData = LoadingData.shared
    @State private var showingAlert = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                CircularProgressBar(value: $loadingData.progressValue)
                        .frame(width: 250.0, height: 250.0)
                        .padding(.bottom, 20)
                        .padding(.trailing, 40)
                        .padding(.leading, 40)
                        .padding(.top, 40)
                if loadingData.error == nil && loadingData.warning == nil {
                    AnimatedText(text: NSLocalizedString("SYNCING DATA", comment: ""))
                }
                if (loadingData.error != nil){
                    Text(loadingData.error!)
                        .font(.title)
                        .foregroundColor(Color.red)
                } else if loadingData.warning != nil {
                    Text(loadingData.warning!)
                            .font(.title)
                            .foregroundColor(Color.orange)
                    Button(action: {
                        STMCoreAuthController.shared().initialLoadingError = false
                        STMCoreSessionManager.shared()?.currentSession.syncer.receiveData()
                        loadingData.warning = nil
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title)
                            Text("TRY AGAIN")
                                    .fontWeight(.semibold)
                                    .font(.headline)
                        }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .padding(.horizontal, 20)
                    }
                }
                Spacer()
                Spacer()
            }
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
                                    LoadingData.shared.progressValue = 0
                                    (UIApplication.shared.delegate as! STMCoreAppDelegate).setupWindow()
                                }
                                ),
                                secondaryButton: Alert.Button.cancel(
                                        Text("CANCEL"), action: {
                                    showingAlert = false
                                }
                                )
                        )
                    })
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
