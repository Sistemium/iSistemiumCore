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
            let document = STMCoreSessionManager.sharedManager().currentSession.document
            let photoFetchRequest = STMFetchRequest(entityName: NSStringFromClass(STMCorePicture))
            let allImages = try document.managedObjectContext.executeFetchRequest(photoFetchRequest) as! [STMCorePicture]
            for image in allImages{
                if let date = image.deviceAts, let entityName = image.entity.name, let pictureLifeTime = (STMEntityController.stcEntities()[entityName] as? STMEntity)?.pictureLifeTime{
                    if Double(NSCalendar.currentCalendar().components(.Hour, fromDate: date, toDate: NSDate(), options: []).hour) > Double(pictureLifeTime){
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
            }
        } catch let error as NSError {
            NSLog(error.description)
        }
    }
}
