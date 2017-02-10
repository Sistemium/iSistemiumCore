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
    static var outOfDateImages = Set<STMCorePicture>()
    
    static func removeUnusedImages(){
        DispatchQueue.global(qos: .default).async{
            do {
                searchUnusedImages()
                if unusedImageFiles.count > 0 {
                    let logMessage = String(format: "Deleting %i images",unusedImageFiles.count)
                    STMLogger.shared().saveLogMessage(withText: logMessage, type:"important")
                }
                for unusedImage in unusedImageFiles{
                    try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+unusedImage)
                    self.unusedImageFiles.remove(unusedImage)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "unusedImageRemoved"), object: nil)
                }
            } catch let error as NSError {
                NSLog(error.description)
            }
        }
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
        
        let allImages = STMCorePicturesController.allPictures() as! Array<STMCorePicture>;
        for image in allImages{
            if let path = image.imagePath{
                usedImageFiles.insert(path)
            }
            if let resizedPath = image.resizedImagePath{
                usedImageFiles.insert(resizedPath)
            }
            if let thumbnailPath = image.thumbnailPath{
                usedImageFiles.insert(thumbnailPath)
            }
        }
        unusedImageFiles = allImageFiles.subtracting(usedImageFiles)
        unusedImageFiles = unusedImageFiles.setmap{imageFilePaths[$0]!}
    }
    
    static func removeOutOfDateImages(){
        do {
            if (!Thread.isMainThread){
                CLSLogv("removeOutOfDateImages called not from main thread", getVaList([""]))
            }
            let entityPredicate = NSPredicate(format: "pictureLifeTime > 0")
            
            let stcEntities:NSDictionary
            
            if STMEntityController.stcEntities() != nil{
                stcEntities = STMEntityController.stcEntities() as NSDictionary
            }else{
                return
            }
            
            let entities = stcEntities.filter{entityPredicate.evaluate(with: $1)}

            for (key,value) in entities {
                
                let entity = (value as! STMEntity)
                let limitDate = Date().addingTimeInterval(-1 * Double(entity.pictureLifeTime!))
                
                let photoIsUploaded = NSPredicate(format: "href != nil")
                let photoIsSynced = NSPredicate(format: "deviceTs <= lts")
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [limitDate, limitDate])
                
                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]
                
                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                
                var images = try STMCoreSessionManager.shared().currentSession.persistenceDelegate.findAllSync(key as! String, predicate: photoPredicate, options: nil)
                
                images = images.filter{photoPredicate.evaluate(with: $0)};
                
                for image in images as! Array<STMCorePicture>{
                    
                    let logMessage = String(format: "removeOutOfDateImages for:\(entity.name) deviceAts:\(image.deviceAts)")
                    STMLogger.shared().saveLogMessage(withText: logMessage, numType: STMLogMessageType.info)
                    
                    if let imagePath = image.imagePath{
                        try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+imagePath)
                        image.imagePath = nil
                    }
                    
                    if let resizedImagePath = image.resizedImagePath{
                        try FileManager.default.removeItem(atPath: STMFunctions.documentsDirectory()+"/"+resizedImagePath)
                        image.resizedImagePath = nil
                    }
                    
                }
                
            }
            
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
}
