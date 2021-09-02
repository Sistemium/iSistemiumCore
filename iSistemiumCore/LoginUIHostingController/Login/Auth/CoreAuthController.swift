//
//  CoreAuthController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-08-24.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import Alamofire

class CoreAuthController{
    
    private static let AUTH_URL = "https://api.sistemium.com/pha/auth"
    private static let ROLES_URL = "https://api.sistemium.com/pha/roles"
    private static let VFS_ROLES_URL = "https://oauth.it/api/roles"
    
    static var phoneNumber: String?{

        get {
            return UserDefaults.standard.string(forKey: "phoneNumber")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "phoneNumber")
            defaults.synchronize()
        }
    }
    
    static var entityResource: String?{

        get {
            return UserDefaults.standard.string(forKey: "entityResource")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "entityResource")
            defaults.synchronize()
        }
    }
    
    static var socketURL: String?{

        get {
            return UserDefaults.standard.string(forKey: "socketURL")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "socketURL")
            defaults.synchronize()
        }
    }
    
    static var userID: String?{

        get {
            return UserDefaults.standard.string(forKey: "userID")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "userID")
            defaults.synchronize()
        }
    }
    
    static var userName: String?{

        get {
            return UserDefaults.standard.string(forKey: "userName")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "userName")
            defaults.synchronize()
        }
    }
    
    static var accessToken: String?{

        get {
            return UserDefaults.standard.string(forKey: "accessToken")
        }

        set {
            let defaults = UserDefaults.standard
            defaults.setValue(newValue, forKey: "accessToken")
            defaults.synchronize()
        }
    }
    
    static func sendPhoneNumber(phoneNumber:String) -> Promise<String>{
        
        return Promise { promise in
            
            var _phoneNumber = phoneNumber;
            
            if (phoneNumber.starts(with: "+7")){
                self.phoneNumber = phoneNumber
                _phoneNumber = _phoneNumber.replacingOccurrences(of: "+7", with: "8")
            }
            
            if(STMFunctions.isCorrectPhoneNumber(_phoneNumber)){
                let request = AF.request(AUTH_URL + "?mobileNumber=" + _phoneNumber)
                request.responseJSON { (data) in
                    if (data.data != nil){
                        let unwrappedData = data.data!
                        let responseID = ((try? JSONSerialization.jsonObject(with: unwrappedData, options: .mutableContainers)) as? [String:String])?.first?.value
                        promise.fulfill(responseID!)
                    } else {
                        promise.reject(NSError())
                    }
                }
            }
                        
        }
        
    }
    
    static func sendSMSCode(requestID:String, SMSCode:String) -> Promise<Void>{
        
        return Promise { promise in
            
            if(STMFunctions.isCorrectSMSCode(SMSCode)){
                let request = AF.request(AUTH_URL + "?smsCode="+SMSCode+"&ID=" + requestID)
                request.responseJSON { (data) in
                    if (data.data != nil){
                        let unwrappedData = data.data!
                        let data = ((try? JSONSerialization.jsonObject(with: unwrappedData, options: .mutableContainers)) as? [String:String])!
                        self.entityResource = data["redirectUri"]
                        self.socketURL = data["apiUrl"]
                        self.userID = data["ID"]
                        self.userName = data["name"]
                        self.accessToken = data["accessToken"]
                        promise.fulfill(Void())
                    } else {
                        promise.reject(NSError())
                    }
                }
            }
            
        }
        
    }
    
    static func requestRoles() -> Promise<Void>{
        
        return Promise { promise in
            
            #if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)
                
            #endif
            
            let request = AF.request(ROLES_URL + "?smsCode="+SMSCode+"&ID=" + requestID)
            request.responseJSON { (data) in
                if (data.data != nil){
                    let unwrappedData = data.data!
                    let data = ((try? JSONSerialization.jsonObject(with: unwrappedData, options: .mutableContainers)) as? [String:String])!
                    self.entityResource = data["redirectUri"]
                    self.socketURL = data["apiUrl"]
                    self.userID = data["ID"]
                    self.userName = data["name"]
                    self.accessToken = data["accessToken"]
                    promise.fulfill(Void())
                } else {
                    promise.reject(NSError())
                }
            }
            
        }
        
    }
    
}
