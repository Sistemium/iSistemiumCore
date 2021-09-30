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
    
}
