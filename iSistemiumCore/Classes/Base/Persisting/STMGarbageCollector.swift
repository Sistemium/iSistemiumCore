//
//  STMGarbageCollector.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 19/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import Foundation
import Crashlytics

@objc class STMGarbageCollector:NSObject{
    
    static let sharedInstance = STMGarbageCollector()
    
    private override init() {}
    
    private var _unusedImageFiles:Set<String>?
    
    private var _filing:STMFiling?
    
    var filing:STMFiling{
        get{
            return _filing != nil ? _filing! : STMCoreSessionManager.shared().currentSession.filing
        }
        set{
            _filing = newValue
        }
        
    }
    
    var unusedImageFiles : Set<String>{
        get{
            if _unusedImageFiles == nil{
                searchUnusedImages()
            }
            return _unusedImageFiles!
        }
        
        set{
            _unusedImageFiles = newValue
        }
    }
    
    func removeUnusedImages() -> AnyPromise{
        
        return AnyPromise.promiseWithResolverBlock({ resolve in
            
            DispatchQueue.global(qos: .default).async{[unowned self] in
                var err:NSError? = nil
                do {
                    self.searchUnusedImages()
                    if self.unusedImageFiles.count > 0 {
                        let logMessage = String(format: "Deleting %i images",self.unusedImageFiles.count)
                        STMLogger.shared().saveLogMessage(withText: logMessage, numType:STMLogMessageType.important)
                    }
                    for unusedImage in self.unusedImageFiles{
                        try self.filing.removeItem(atPath: self.filing.picturesBasePath() + "/" + unusedImage)
                        self.unusedImageFiles.remove(unusedImage)
                        NotificationCenter.default.post(name: Notification.Name(rawValue: NOTIFICATION_PICTURE_UNUSED_CHANGE), object: nil)
                    }
                } catch let error as NSError {
                    err = error
                    NSLog(error.description)
                    
                }
                resolve(err)
            }
            
        })
        
    }
    
    func searchUnusedImages(){
        var unusedImageFiles = Set<String>()
        var allImageFiles = Set<String>()
        var usedImageFiles = Set<String>()
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: self.filing.picturesBasePath())
        while let element = enumerator?.nextObject() as? String {
            if element.hasSuffix(".jpg") {
                allImageFiles.insert(element)
            }
        }
        
        let allImages = STMCorePicturesController.allPictures() as! Array<Dictionary<String,Any>>;
        for image in allImages{
            
            let data = image["attributes"] as! Dictionary<String,Any>
        
            if let path = data["imagePath"] as? String{
                usedImageFiles.insert(path)
            }
            if let resizedPath = data["resizedImagePath"] as? String{
                usedImageFiles.insert(resizedPath)
            }
            if let thumbnailPath = data["thumbnailPath"] as? String{
                usedImageFiles.insert(thumbnailPath)
            }
        }
        unusedImageFiles = allImageFiles.subtracting(usedImageFiles)
        
        self.unusedImageFiles = unusedImageFiles
    }
    
    func removeOutOfDateImages(){
        do {
            let entityPredicate = NSPredicate(format: "pictureLifeTime > 0")
            
            let stcEntities:Dictionary<String, NSDictionary>
            
            if STMEntityController.stcEntities() != nil{
                stcEntities = STMEntityController.stcEntities() as Dictionary<String, NSDictionary>
            }else{
                return
            }
            
            let entities = stcEntities.filter{entityPredicate.evaluate(with: $1)}

            for (key,value) in entities {
                
                let entity = (value as! Dictionary<String, Any>)
                let limitDate = Date().addingTimeInterval(-(entity["pictureLifeTime"] as! Double))
                
                let photoIsUploaded = NSPredicate(format: "href != nil")
                let photoIsSynced = NSPredicate(format: "deviceTs <= lts")
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil OR thumbnailPath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [limitDate, limitDate])
                
                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]
                
                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                
                var images = try STMCoreSessionManager.shared().currentSession.persistenceDelegate.findAllSync(key, predicate: photoPredicate, options: nil) as! Array<Dictionary<String,Any>>
                
                images = images.filter{photoPredicate.evaluate(with: $0)};
                
                for var image in images{
                    
                    let logMessage = String(format: "removeOutOfDateImages for:\(entity["name"]) deviceAts:\(image["deviceAts"])")
                    STMLogger.shared().saveLogMessage(withText: logMessage, numType: STMLogMessageType.info)
                    
                    if let imagePath = image["imagePath"] as? String{
                        try filing.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+imagePath)
                        image["imagePath"] = nil
                    }
                    
                    if let resizedImagePath = image["resizedImagePath"] as? String{
                        try filing.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+resizedImagePath)
                        image["resizedImagePath"] = nil
                    }
                    
                }
                
                try STMCoreSessionManager.shared().currentSession.persistenceDelegate.mergeManySync(key, attributeArray: images, options: nil)
                
            }
            
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
}
