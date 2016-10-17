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
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            do {
                if unusedImageFiles.count > 0 {
                    let logMessage = String(format: "Deleting %i images",unusedImageFiles.count)
                    STMLogger.sharedLogger().saveLogMessageWithText(logMessage, type:"important")
                }
                for unusedImage in unusedImageFiles{
                    try NSFileManager.defaultManager().removeItemAtPath(STMFunctions.documentsDirectory()+"/"+unusedImage)
                    self.unusedImageFiles.remove(unusedImage)
                    NSNotificationCenter.defaultCenter().postNotificationName("unusedImageRemoved", object: nil)
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
            let document = STMCoreSessionManager.sharedManager().currentSession.document
            let fileManager = NSFileManager.defaultManager()
            let enumerator = fileManager.enumeratorAtPath(STMFunctions.documentsDirectory())
            while let element = enumerator?.nextObject() as? String {
                if element.hasSuffix(".jpg") {
                    allImageFiles.insert(element)
                }
            }
            let photoFetchRequest = STMFetchRequest(entityName: NSStringFromClass(STMCorePicture))
            let allImages = try document.managedObjectContext.executeFetchRequest(photoFetchRequest) as! [STMCorePicture]
            for image in allImages{
                if let path = image.imagePath{
                    usedImageFiles.insert(path)
                }
                if let resizedPath = image.resizedImagePath{
                    usedImageFiles.insert(resizedPath)
                }
            }
            unusedImageFiles = allImageFiles.subtract(usedImageFiles)
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
    
    static func removeOutOfDateImages(){
        do {
            let entityPredicate = NSPredicate(format: "pictureLifeTime > 0")
            let entities = (STMEntityController.stcEntities() as NSDictionary).filter{entityPredicate.evaluateWithObject($1)}
            let document = STMCoreSessionManager.sharedManager().currentSession.document

            for (key,value) in entities {
                
                let entity = (value as! STMEntity)
                let photoFetchRequest = STMFetchRequest(entityName: key as! String)
                let limitDate = NSDate().dateByAddingTimeInterval(-3600 * Double(entity.pictureLifeTime!))
                
                let photoIsUploaded = NSPredicate(format: "href != nil")
                let photoIsSynced = NSPredicate(format: "deviceTs <= lts")
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [limitDate, limitDate])
                
                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]
                
                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                
                photoFetchRequest.predicate = photoPredicate
                
                let images = try document.managedObjectContext.executeFetchRequest(photoFetchRequest) as! [STMCorePicture]
                
                for image in images{
                    
                    let logMessage = String(format: "removeOutOfDateImages for:\(entity.name) deviceAts:\(image.deviceAts)")
                    STMLogger.sharedLogger().saveLogMessageWithText(logMessage, numType: STMLogMessageType.Info)
                    
                    if let imagePath = image.imagePath{
                        try NSFileManager.defaultManager().removeItemAtPath(STMFunctions.documentsDirectory()+"/"+imagePath)
                        image.imagePath = nil
                    }
                    
                    if let resizedImagePath = image.resizedImagePath{
                        try NSFileManager.defaultManager().removeItemAtPath(STMFunctions.documentsDirectory()+"/"+resizedImagePath)
                        image.resizedImagePath = nil
                    }
                    
                }
                
            }
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
}
