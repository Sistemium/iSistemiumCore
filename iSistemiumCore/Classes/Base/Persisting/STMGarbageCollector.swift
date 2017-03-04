//
//  STMGarbageCollector.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 19/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import Foundation
import Crashlytics

extension Set {
    func setmap<U>(transform: (Element) -> U) -> Set<U> {
        return Set<U>(self.lazy.map(transform))
    }
}

@objc class STMGarbageCollector:NSObject{
    
    static var unusedImageFiles = Set<String>()
    
    static func removeUnusedImages() -> AnyPromise{
        
        return AnyPromise.promiseWithResolverBlock({ resolve in
            
            DispatchQueue.global(qos: .default).async{
                var err:NSError? = nil
                do {
                    searchUnusedImages()
                    if unusedImageFiles.count > 0 {
                        let logMessage = String(format: "Deleting %i images",unusedImageFiles.count)
                        STMLogger.shared().saveLogMessage(withText: logMessage, numType:STMLogMessageType.important)
                    }
                    for unusedImage in unusedImageFiles{
                        try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+unusedImage)
                        self.unusedImageFiles.remove(unusedImage)
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "unusedImageRemoved"), object: nil)
                    }
                } catch let error as NSError {
                    err = error
                    NSLog(error.description)
                    
                }
                resolve(err)
            }
            
        })
        
    }
    
    static func searchUnusedImages(){
        unusedImageFiles = Set<String>()
        var allImageFiles = Set<String>()
        var usedImageFiles = Set<String>()
        var imageFilePaths = Dictionary<String,String>()
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: STMFunctions.documentsDirectory())
        while let element = enumerator?.nextObject() as? String {
            if element.hasSuffix(".jpg") {
                let name = element.components(separatedBy: "/").last!
                allImageFiles.insert(name)
                imageFilePaths[name] = element
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
        unusedImageFiles = unusedImageFiles.setmap{imageFilePaths[$0]!}
    }
    
    static func removeOutOfDateImages(){
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
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [limitDate, limitDate])
                
                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]
                
                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                
                var images = try STMCoreSessionManager.shared().currentSession.persistenceDelegate.findAllSync(key, predicate: photoPredicate, options: nil) as! Array<Dictionary<String,String>>
                
                images = images.filter{photoPredicate.evaluate(with: $0)};
                
                for var image in images{
                    
                    let logMessage = String(format: "removeOutOfDateImages for:\(entity["name"]) deviceAts:\(image["deviceAts"])")
                    STMLogger.shared().saveLogMessage(withText: logMessage, numType: STMLogMessageType.info)
                    
                    if let imagePath = image["imagePath"]{
                        try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+imagePath)
                        image["imagePath"] = nil
                    }
                    
                    if let resizedImagePath = image["resizedImagePath"]{
                        try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+resizedImagePath)
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
