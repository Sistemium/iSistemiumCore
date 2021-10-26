//
//  Profile.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-10-25.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

struct Profile: View {
    
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView{
            VStack{
                Text("test")
            }
            .navigationBarTitle("\(STMCoreSessionManager.shared()?.currentSession?.currentAppVersion ?? "")", displayMode: .inline)
            .navigationBarItems(leading:
                Button(action: {
                    showingAlert = true
                
                }) {
                    Image(uiImage: STMFunctions.resize(UIImage(named: "exit-128.png")?.withTintColor(.blue), to: CGSize(width: 22,height: 22)))
                }.alert(isPresented: self.$showingAlert) {
                    Alert(title: Text("LOGOUT"), message: Text("R U SURE TO LOGOUT"),
                        primaryButton: Alert.Button.default(
                            Text("OK"), action: {
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
