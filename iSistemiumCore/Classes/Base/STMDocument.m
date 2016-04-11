//
//  STMDocument.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMDocument.h"
#import "STMObjectsController.h"

#define SAVING_QUEUE_THRESHOLD 15

@interface STMDocument()

@property (nonatomic, strong) NSString *dataModelName;
@property (nonatomic) BOOL saving;
@property (nonatomic) int savingQueue;

@end


@implementation STMDocument

@synthesize myManagedObjectModel = _myManagedObjectModel;
//@synthesize mainContext = _mainContext;
//@synthesize privateContext = _privateContext;

- (NSManagedObjectModel *)myManagedObjectModel {
    
    if (!_myManagedObjectModel) {
        
        NSString *path = [[NSBundle mainBundle] pathForResource:self.dataModelName ofType:@"momd"];
        
        if (!path) {
            path = [[NSBundle mainBundle] pathForResource:self.dataModelName ofType:@"mom"];
        }
        
        NSURL *url = [NSURL fileURLWithPath:path];

        //        NSLog(@"path %@", path);
        //        NSLog(@"url %@", url);

        _myManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        
    }
    
    return _myManagedObjectModel;
    
}

- (NSManagedObjectModel *)managedObjectModel {
    return self.myManagedObjectModel;
}

//- (NSManagedObjectContext *)mainContext {
//    
//    if (!_mainContext) {
//        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
//        _mainContext.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
//    }
//    return _mainContext;
//    
//}

//- (NSManagedObjectContext *)privateContext {
//    
//    if (!_privateContext) {
//        _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
//        _privateContext.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
//    }
//    return _privateContext;
//    
//}

//- (void)saveContexts {
//    
//    [self.mainContext performBlock:^{
//        if (self.mainContext.hasChanges) [self.mainContext save:nil];
//    }];
//    
//    [self.privateContext performBlock:^{
//        if (self.privateContext.hasChanges) [self.privateContext save:nil];
//    }];
//    
//}

- (void)saveDocument:(void (^)(BOOL success))completionHandler {

//    [self saveContexts];
    
    if (!self.saving) {

        if (self.documentState == UIDocumentStateNormal) {
            
            self.saving = YES;
            
            [self saveToURL:self.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                
                if (success) {

//                    NSLog(@"UIDocumentSaveForOverwriting success");
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"documentSavedSuccessfully" object:self];
                    
                    completionHandler(YES);

                } else {
                    
                    NSLog(@"UIDocumentSaveForOverwriting not success");
                    completionHandler(NO);
                    
                }
                
                self.saving = NO;
                
            }];
            
        } else {
            
            NSLog(@"documentState != UIDocumentStateNormal for document: %@", self);
            NSLog(@"documentState is %u", (int)self.documentState);
            
            completionHandler(NO);
            
        }

    } else {

//        NSLog(@"Document currently is saving");
        completionHandler(YES);

//        double delayInSeconds = 3;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//
//            [self saveDocument:^(BOOL success) {
//                
//                completionHandler(success);
//                
//            }];
//            
//        });

    }

}

//- (void)contextDidSaveMainContext:(NSNotification *)notification {
//    
//    @synchronized(self) {
//        [self.privateContext performBlock:^{
//            [self.privateContext mergeChangesFromContextDidSaveNotification:notification];
//        }];
//    }
//    
//}

//- (void)contextDidSavePrivateContext:(NSNotification *)notification {
//    
//    @synchronized(self) {
//        [self.mainContext performBlock:^{
//            [self.mainContext mergeChangesFromContextDidSaveNotification:notification];
//        }];
//    }
//    
//}

- (void)downloadPicture:(NSNotification *)notification {
    
    if (++self.savingQueue > SAVING_QUEUE_THRESHOLD) {
        self.savingQueue = 0;
        [self saveDocument: ^(BOOL success) {
            NSLog(@"STMDocument save success on downloadPicture");
        }];
    }
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(applicationDidEnterBackground)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    
//#warning - have to comment out NSManagedObjectContextDidSaveNotification?
//https://crashlytics.com/sistemium2/ios/apps/com.sistemium.isistemium/issues/55688ca9f505b5ccf0fa0b11/sessions/5568725f03df0001057a643230626339
    
//    [nc addObserver:self
//           selector:@selector(contextDidSaveMainContext:)
//               name:NSManagedObjectContextDidSaveNotification
//             object:self.mainContext];
    
//    [nc addObserver:self
//           selector:@selector(contextDidSavePrivateContext:)
//               name:NSManagedObjectContextDidSaveNotification
//             object:self.privateContext];
    
    [nc addObserver:self
           selector: @selector(downloadPicture:)
               name:@"downloadPicture"
             object: nil];
    
}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)applicationDidEnterBackground {
    
    [STMObjectsController checkObjectsForFlushing];
    
}

+ (STMDocument *)initWithFileURL:(NSURL *)url andDataModelName:(NSString *)dataModelName {
    
    STMDocument *document = [STMDocument alloc];
    [document setDataModelName:dataModelName];
    return [document initWithFileURL:url];
    
}

+ (STMDocument *)documentWithUID:(NSString *)uid iSisDB:(NSString *)iSisDB dataModelName:(NSString *)dataModelName prefix:(NSString *)prefix {

    NSURL *documentDirectoryUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSString *documentID = (iSisDB) ? iSisDB : uid;

//    from now we delete old document with STMDataModel data model and use new STMDataModel2
    NSURL *url = [documentDirectoryUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.%@", prefix, documentID, @"sqlite"]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:(NSString *)url.path]) {

        NSString *logMessage = [NSString stringWithFormat:@"delete old document with filename: %@ for uid: %@", url.lastPathComponent, uid];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];
        
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        
    }
//    ———————————————————————
    
    NSString *filename = [@[prefix, documentID, dataModelName] componentsJoinedByString:@"_"];
    url = [documentDirectoryUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", filename, @"sqlite"]];

    NSString *logMessage = [NSString stringWithFormat:@"prepare document with filename: %@ for uid: %@", url.lastPathComponent, uid];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];

    STMDocument *document = [STMDocument initWithFileURL:url andDataModelName:dataModelName];
    
    document.persistentStoreOptions = @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
    
    if (document.fileURL.path && ![[NSFileManager defaultManager] fileExistsAtPath:(NSString * _Nonnull)document.fileURL.path]) {

        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            
            if (success) {
                
                NSString *logMessage = @"document UIDocumentSaveForCreating success";
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];
                
                [self document:document readyWithUID:uid];
                
            } else {
                [self document:document notReadyWithUID:uid];
            }
            
        }];
        
    } else if (document.documentState == UIDocumentStateClosed) {
        
        [document openWithCompletionHandler:^(BOOL success) {
            
            if (success) {

                NSString *logMessage = @"document openWithCompletionHandler success";
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];

                [self document:document readyWithUID:uid];
            } else {
                [self document:document notReadyWithUID:uid];
            }
            
        }];
        
    } else if (document.documentState == UIDocumentStateNormal) {
        
        [self document:document readyWithUID:uid];
        
    }
    
    [document addObservers];
    
    [[document undoManager] disableUndoRegistration];

    return document;
    
}

+ (void)document:(STMDocument *)document readyWithUID:(NSString *)uid {

    [[NSNotificationCenter defaultCenter] postNotificationName:@"documentReady" object:document userInfo:@{@"uid": uid}];

}

+ (void)document:(STMDocument *)document notReadyWithUID:(NSString *)uid {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"documentNotReady" object:document userInfo:@{@"uid": uid}];
    
}


@end
