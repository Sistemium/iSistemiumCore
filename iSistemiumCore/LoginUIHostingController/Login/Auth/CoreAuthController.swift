//
//  CoreAuthController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-08-24.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import Alamofire

@objc
class CoreAuthController:NSObject{

    // old obc code uses observer pattern. It is hard to revrite it, better to call this resolve from observers
    static private var resolver:Resolver<Void>? = nil
    
    @objc
    static func resolve(){
        resolver?.fulfill(Void())
    }
    
    @objc
    static func reject(error:String){
        resolver?.reject(NSError(domain: "", code: 0, userInfo: ["error": error]))
    }
    
    static func checkPhoneNumber() -> Promise<Void>{
                
        return Promise { _promise in
            
            self.resolver = _promise
                        
        }
        
    }
    
    static func sendPhoneNumber(phoneNumber:String) -> Promise<Void>{
                
        return Promise { _promise in
            
            var _phoneNumber = phoneNumber;
            
            if (_phoneNumber.starts(with: "+7")){
                _phoneNumber = _phoneNumber.replacingOccurrences(of: "+7", with: "8")
            }
            
            _phoneNumber = _phoneNumber.replacingOccurrences(of: " ", with: "")
            
            self.resolver = _promise
            
            STMCoreAuthController.shared().sendPhoneNumber(_phoneNumber)
                        
        }
        
    }
    
    static func sendSMSCode(SMSCode:String) -> Promise<Void>{
                
        return Promise { _promise in
                        
            self.resolver = _promise
            
            STMCoreAuthController.shared().sendSMSCode(SMSCode)
                        
        }
        
    }
    
    static func demoAuth(){
        
        STMCoreAuthController.shared().phoneNumber = "+7 DEMO 000"
        STMCoreAuthController.shared().accessToken = "DEMO TOKEN"
        STMCoreAuthController.shared().accountOrg = "DEMO ORG"
        STMCoreAuthController.shared().socketURL = "DEMO SOCKET"
        STMCoreAuthController.shared().entityResource = "DEMO SOCKET"
        STMCoreAuthController.shared().userID = "DEMO USER ID"
        STMCoreAuthController.shared().userName = "DEMO USER"
        STMCoreAuthController.shared().processRoles(
            [
                "ts" : "2021-10-06 11:47:03.522",
                "token": [
                    "expiresAt": "2022-10-06 11:46:20.764",
                    "expiresIn": 31533909,
                ],
                "account": [
                    "authId": "DEMO AUTH ID",
                    "code": 635,
                    "email": "email@email.com",
                    "mobile-number": "+7 DEMO 000",
                    "org" : "DEMO ORG",
                    "name": "DEMO ACC",
                ],
                "cts": "2021-10-06 11:46:20.764",
                "id": "DEMO ID",
                "roles": [
                    "authenticated": 1,
                    "mailer": 1,
                    "models": "iSisSales",
                    "org": "DEMO ORG",
                    "saleType": "op",
                    "salesman": 77495,
                    "stc": 1,
                    "tester": 1,
                    "stcTabs": [
                        [
                            "imageName": "checked_user-128.png",
                            "name": "STMProfile",
                            "title": "Профиль",
                        ],
                        [
                            "disableScroll": 1,
                            "imageName": "3colors-colorless.png",
                            "name": "STMWKWebView",
                            "title": "Демо1",
                            "url": "DEMO URL"
                        ],
                        [
                            "disableScroll": 1,
                            "imageName": "3colors-colorless.png",
                            "name": "STMWKWebView",
                            "title": "Демо2",
                            "url": "DEMO URL"
                        ],
                        [
                            "disableScroll": 1,
                            "imageName": "3colors-colorless.png",
                            "name": "STMWKWebView",
                            "title": "Демо3",
                            "appManifestURI": "https://isd.sistemium.com/app.manifest",
                        ],
                    ]
                ],
            ]
        )
    }
    
}
