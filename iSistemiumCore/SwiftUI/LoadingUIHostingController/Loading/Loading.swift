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
        DispatchQueue.main.async {
            LoadingData.shared.progressValue = value
            if (value == 1.0){
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    LoadingData.shared.isLoading = false
                }
            } else {
                LoadingData.shared.isLoading = true
            }
        }
    }
}

class LoadingData: ObservableObject {
    static let shared = LoadingData()
    @Published var progressValue: Float = 0
    @Published var isLoading: Bool = true
}

struct Loading: View{

    @ObservedObject var loadingData: LoadingData = LoadingData.shared

    var body: some View {
        VStack {
            Spacer().frame(height: 100)
            if(loadingData.isLoading){
                CircularProgressBar(value: $loadingData.progressValue)
                        .frame(width: 150.0, height: 150.0)
                        .padding(.bottom, 20)
                        .padding(.trailing, 40)
                        .padding(.leading, 40)
                        .padding(.top, 40)
                SyncingData()
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
    }
}
