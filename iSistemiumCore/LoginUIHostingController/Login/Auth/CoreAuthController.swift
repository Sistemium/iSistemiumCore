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
    
    static func sendPhoneNumber(phoneNumber:String) -> Promise<Data>{
        
        return Promise { promise in
            
            var _phoneNumber = phoneNumber;
            
            if (phoneNumber.starts(with: "+7")){
                _phoneNumber = _phoneNumber.replacingOccurrences(of: "+7", with: "8")
            }
            
            if(STMFunctions.isCorrectPhoneNumber(_phoneNumber)){
                let request = AF.request(AUTH_URL + "?mobileNumber=" + _phoneNumber)
                request.responseJSON { (data) in
                    if (data.data != nil){
                        promise.fulfill(data.data!)
                    } else {
                        promise.reject(NSError())
                    }
                }
            }
                        
        }
        
    }
    
}
