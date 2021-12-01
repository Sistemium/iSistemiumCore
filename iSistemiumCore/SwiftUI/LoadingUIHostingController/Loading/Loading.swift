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
    static func setProgress(value: Float) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animation.linear(duration: 0.1)) {
                LoadingData.shared.progressValue = value
            }
        }
        if (value >= 1.0){
            STMCoreAuthController.shared().initialLoadingCompleted = true
            (UIApplication.shared.delegate as! STMCoreAppDelegate).setupWindow()
        }
    }
}

class LoadingData: ObservableObject {
    static let shared = LoadingData()
    @Published var progressValue: Float = 0
}

struct Loading: View{

    @ObservedObject var loadingData: LoadingData = LoadingData.shared
    @State private var showingAlert = false


    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                CircularProgressBar(value: $loadingData.progressValue)
                        .frame(width: 200.0, height: 200.0)
                        .padding(.bottom, 20)
                        .padding(.trailing, 40)
                        .padding(.leading, 40)
                        .padding(.top, 40)
                AnimatedText(text: "SYNCING DATA".localizedCapitalized)
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
                                    (UIApplication.shared.delegate as! STMCoreAppDelegate).window = nil
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
        }
    }
}
