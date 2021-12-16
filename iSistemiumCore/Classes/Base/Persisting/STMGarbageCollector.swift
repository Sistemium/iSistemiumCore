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

@objcMembers
class STMGarbageCollector: NSObject {

    static let sharedInstance = STMGarbageCollector()
    
    private var removingUnusedImages = false

    private var _unusedImageFiles: Set<String>?

    private var _filing: STMFiling?

    var filing: STMFiling {
        get {
            return _filing != nil ? _filing! : STMCoreSessionManager.shared().currentSession.filing

//FIXME: app crash in line above if login and immediately logout, possibly due to checkNotUploadedPhotos process

//            Log info: Session #244 status changed to STMSessionFinishing
//            Log info: Session #244 status changed to STMSessionStopped
//            userID (null)
//            accessToken (null)
//            Warning: Attempt to present <UIAlertController: 0x7ff12ec8b570> on <STMProfileVC: 0x7ff128d6d660> whose view is not in the window hierarchy!
//            Can't find keyplane that supports type 4 for keyboard iPhone-Portrait-NumberPad; using 160517473_Portrait_iPhone-Simple-Pad_Default
//            checkNotUploadedPhotos
//            checkPhotos finish
//            STMCoreSettingsController.m:46 - dealloc
//            fatal error: unexpectedly found nil while unwrapping an Optional value

        }
        set {
            _filing = newValue
        }

    }

    var unusedImageFiles: Set<String> {
        get {
            if _unusedImageFiles == nil {
                searchUnusedImages()
            }
            return _unusedImageFiles!
        }

        set {
            _unusedImageFiles = newValue
        }
    }

    @discardableResult
    @objc
    func removeUnusedImages() -> AnyPromise {
        
        removingUnusedImages = true

        return AnyPromise(Promise<Any>{ seal in

            DispatchQueue.global(qos: .default).async { [unowned self] in
                var err: NSError? = nil
                do {
                    self.searchUnusedImages()
                    if self.unusedImageFiles.count > 0 {
                        let logMessage = String(format: "Deleting %i images", self.unusedImageFiles.count)
                        STMLogger.shared().saveLogMessage(withText: logMessage, numType: STMLogMessageType.important)
                    }
                    for unusedImage in self.unusedImageFiles {
                        if (!removingUnusedImages){
                            break;
                        }
                        try self.filing.removeItem(atPath: unusedImage)
                        self.unusedImageFiles.remove(unusedImage)
                        ProfileDataObjc.setUnusedPhotos(value: unusedImageFiles.count)
                    }
                } catch let error as NSError {
                    err = error
                    NSLog(error.description)

                }
                seal.resolve("", err)
            }

        })

    }
    
    func stopRemoveUnusedImages(){
        
        removingUnusedImages = false

    }

    func searchUnusedImages() {
        var unusedImageFiles = Set<String>()
        var allImageFiles = Set<String>()
        var usedImageFiles = Set<String>()
        var imageFilePaths = Dictionary<String, String>()

        self.filing.enumerateDir(atPath: self.filing.picturesBasePath()) { (element, error) -> Bool in
            if element!.hasSuffix(".jpg") {
                let components = element!.components(separatedBy: "/")
                let name = components[components.endIndex - 2] + "/" + components[components.endIndex - 1]
                allImageFiles.insert(name)
                imageFilePaths[name] = element
            }
            return true
        }

        let allImages = STMCorePicturesController.shared().allPictures() as! Array<Dictionary<String, Any>>;
        for image in allImages {

            let data = image["attributes"] as! Dictionary<String, Any>

            if let path = data["imagePath"] as? String {
                usedImageFiles.insert(path)
            }
            if let resizedPath = data["resizedImagePath"] as? String {
                usedImageFiles.insert(resizedPath)
            }
            if let thumbnailPath = data["thumbnailPath"] as? String {
                usedImageFiles.insert(thumbnailPath)
            }
        }
        unusedImageFiles = allImageFiles.subtracting(usedImageFiles)
        unusedImageFiles = unusedImageFiles.setmap {
            imageFilePaths[$0]!
        }

        self.unusedImageFiles = unusedImageFiles
    }

    func removeOutOfDateImages() {
        do {
            let entityPredicate = NSPredicate(format: "pictureLifeTime > 0")

            let stcEntities: Dictionary<String, NSDictionary>

            if STMEntityController.stcEntities() != nil {
                stcEntities = STMEntityController.stcEntities() as Dictionary<String, NSDictionary>
            } else {
                return
            }

            let entities = stcEntities.filter {
                entityPredicate.evaluate(with: $1)
            }

            let persistence: STMPersistingSync

            persistence = STMCoreSessionManager.shared().currentSession.persistenceDelegate

            for (key, value) in entities {

                let entity = (value as! Dictionary<String, Any>)
                let limitDate = Date().addingTimeInterval(-(entity["pictureLifeTime"] as! Double))
                let dateString = STMFunctions.string(from: limitDate)

                let photoIsUploaded = NSPredicate(format: "href != nil")
                let photoIsSynced = NSPredicate(format: "deviceTs <= lts")
                let photoHaveFiles = NSPredicate(format: "imagePath != nil OR resizedImagePath != nil OR thumbnailPath != nil")
                let photoIsOutOfDate = NSPredicate(format: "deviceAts < %@ OR (deviceAts == nil AND deviceTs < %@)", argumentArray: [dateString, dateString])

                let subpredicates = [photoIsUploaded, photoIsSynced, photoHaveFiles, photoIsOutOfDate]

                let photoPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

                var images = try STMCoreSessionManager.shared().currentSession.persistenceDelegate.findAllSync(key, predicate: photoPredicate, options: nil) as! Array<Dictionary<String, Any>>

                images = images.filter {
                    photoPredicate.evaluate(with: $0)
                };

                let options: [String: Any] = [
                    STMPersistingOptionFieldsToUpdate: ["imagePath", "resizedImagePath"],
                    STMPersistingOptionSetTs: true
                ]

                for var image in images {

                    let logMessage = String(format: "removeOutOfDateImages for:\(String(describing: entity["name"])) deviceAts:\(String(describing: image["deviceAts"]))")
                    STMLogger.shared().saveLogMessage(withText: logMessage, numType: STMLogMessageType.info)

                    let imagePath = image["imagePath"] as? String
                    let resizedImagePath = image["resizedImagePath"] as? String

                    if (imagePath != nil) {
                        do {
                            try filing.removeItem(atPath: filing.picturesBasePath() + "/" + imagePath!)
                        } catch let error as NSError {
                            NSLog(error.description)
                        }
                        image["imagePath"] = nil
                    }

                    // TODO: need testing
                    if (resizedImagePath != nil && resizedImagePath != imagePath) {
                        do {
                            try filing.removeItem(atPath: filing.picturesBasePath() + "/" + resizedImagePath!)
                        } catch let error as NSError {
                            NSLog(error.description)
                        }
                        image["resizedImagePath"] = nil
                    }

                    try persistence.update(key, attributes: image, options: options)

                }

            }

        } catch let error as NSError {
            NSLog(error.description)
        }
    }
}
