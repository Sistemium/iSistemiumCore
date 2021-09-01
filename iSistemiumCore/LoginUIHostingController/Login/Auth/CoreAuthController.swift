//
//  CoreAuthController.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 2021-08-24.
//  Copyright © 2021 Sistemium UAB. All rights reserved.
//

import Alamofire

class CoreAuthController{
    
    private static let AUTH_URL =  "https://api.sistemium.com/pha/auth"
    
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
                        print(unwrappedData)
                        promise.fulfill(Void())
                    } else {
                        promise.reject(NSError())
                    }
                }
            }
            
        }
        
    }
    
}
