//
//  STMGarbageCollector.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 19/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import Foundation

@objc class STMGarbageCollector:NSObject{
    
    static var unusedImageFiles = Set<String>()
    static var outOfDateImages = Set<STMCorePicture>()
    
    static func removeUnusedImages(){
        DispatchQueue.global(qos: .default).async{
            do {
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
        do {
            unusedImageFiles = Set<String>()
            var allImageFiles = Set<String>()
            var usedImageFiles = Set<String>()
            let document = STMCoreSessionManager.shared().currentSession.document
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(atPath: STMFunctions.documentsDirectory())
            while let element = enumerator?.nextObject() as? String {
                if element.hasSuffix(".jpg") {
                    allImageFiles.insert(element)
                }
            }
            let photoFetchRequest = STMFetchRequest(entityName: NSStringFromClass(STMCorePicture))
            let allImages = try document?.managedObjectContext.fetch(photoFetchRequest) as! [STMCorePicture]
            for image in allImages{
                if let path = image.imagePath{
                    usedImageFiles.insert(path)
                }
                if let resizedPath = image.resizedImagePath{
                    usedImageFiles.insert(resizedPath)
                }
            }
            unusedImageFiles = allImageFiles.subtracting(usedImageFiles)
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
    
    static func removeOutOfDateImages(){
        do {
            let entityPredicate = NSPredicate(format: "pictureLifeTime > 0")
            let entities = (STMEntityController.stcEntities() as NSDictionary).filter{entityPredicate.evaluate(with: $1)}
            let document = STMCoreSessionManager.shared().currentSession.document

            for (key,value) in entities {
                
                let entity = (value as! STMEntity)
                let photoFetchRequest = STMFetchRequest(entityName: key as! String)
                let limitDate = Date().addingTimeInterval(-3600 * Double(entity.pictureLifeTime!))
                
                let photoIsUploaded = NSPredicate(format: "href != nil")
                let photoIsSynced = NSPredicate(format: "deviceTs <= lts")
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [limitDate, limitDate])
                
                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]
                
                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                
                photoFetchRequest.predicate = photoPredicate
                
                let images = try document?.managedObjectContext.fetch(photoFetchRequest) as! [STMCorePicture]
                
                for image in images{
                    
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
