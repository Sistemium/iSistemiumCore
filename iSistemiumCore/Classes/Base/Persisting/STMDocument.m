//
//  STMDocument.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMDocument.h"
#import "STMCoreObjectsController.h"
#import "STMFunctions.h"
#import "STMLogger.h"

@interface STMDocument()

@property (nonatomic, strong) NSString *dataModelName;
@property (nonatomic) BOOL savingHaveToRepeat;
@property (nonatomic) int savingQueue;


@end


@implementation STMDocument

@synthesize myManagedObjectModel = _myManagedObjectModel;

- (NSManagedObjectModel *)myManagedObjectModel {
    
    if (!_myManagedObjectModel) {
        
        NSString *path = [[NSBundle mainBundle] pathForResource:self.dataModelName ofType:@"momd"];
        
        if (!path) path = [[NSBundle mainBundle] pathForResource:self.dataModelName ofType:@"mom"];
        
        if (path) {
        
            NSURL *url = [NSURL fileURLWithPath:path];
            
            //        NSLog(@"path %@", path);
            //        NSLog(@"url %@", url);
            
            _myManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
            
        } else {
            
            NSLog(@"there is no path for data model with name %@", self.dataModelName);
            
        }
        
    }
    
    return _myManagedObjectModel;
    
}

- (NSManagedObjectModel *)managedObjectModel {
    return self.myManagedObjectModel;
}

- (void)saveDocument:(void (^)(BOOL success))completionHandler {
    
    if (!self.isSaving) {
        
        if (self.documentState == UIDocumentStateNormal) {
            
            self.isSaving = YES;
            
//            NSLog(@"--- Document saving start ---");
            
            [self saveToURL:self.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                
                self.isSaving = NO;

                if (success) {
                    
                    if (self.savingHaveToRepeat) {
                        
//                        NSLog(@"--- repeat of Document saving ---");
                        self.savingHaveToRepeat = NO;

                        [self saveDocument:^(BOOL success) {
                            completionHandler(success);
                        }];
                        
                    } else {

                        NSLog(@"--- Document saved successfully ---");
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DOCUMENT_SAVE_SUCCESSFULLY
                                                                            object:self];

                        completionHandler(YES);
                        
                    }
                    
                } else {
                    
                    NSLog(@"--- UIDocumentSaveForOverwriting not success ---");
                    completionHandler(NO);
                    
                    self.savingHaveToRepeat = NO;
                    
                }
                
            }];
            
        } else {
            
            NSLog(@"documentState != UIDocumentStateNormal for document: %@", self);
            NSLog(@"documentState is %u", (int)self.documentState);
            
            completionHandler(NO);
            
        }
        
    } else {
        
        //        NSLog(@"Document currently is saving");
        
        self.savingHaveToRepeat = YES;
        
        completionHandler(YES);

    }
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(applicationDidEnterBackground)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(documentStateChangedNotification:)
               name:UIDocumentStateChangedNotification
             object:self];
    
}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)applicationDidEnterBackground {
    
    [STMCoreObjectsController checkObjectsForFlushing];
    
}

- (void)documentStateChangedNotification:(NSNotification *)notification {
    NSLog(@"notification %@", notification);
}

+ (STMDocument *)initWithFileURL:(NSURL *)url andDataModelName:(NSString *)dataModelName {
    
    STMDocument *document = [STMDocument alloc];
    document.dataModelName = dataModelName;
    return [document initWithFileURL:url];
    
}

+ (STMDocument *)documentWithUID:(NSString *)uid iSisDB:(NSString *)iSisDB dataModelName:(NSString *)dataModelName {

    NSURL *documentDirectoryUrl = [STMFunctions documentsDirectoryURL];
    NSString *documentID = (iSisDB) ? iSisDB : uid;

    NSString *prefix = [NSBundle mainBundle].bundleIdentifier;
    prefix = (prefix) ? prefix : @"";

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
    document.uid = uid;
    
    document.persistentStoreOptions = @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
    
    if (document.fileURL.path && ![[NSFileManager defaultManager] fileExistsAtPath:(NSString * _Nonnull)document.fileURL.path]) {

        [self createDocument:document];
        
    } else if (document.documentState == UIDocumentStateClosed) {
        
        [self openDocument:document];
        
    } else if (document.documentState == UIDocumentStateNormal) {
        
        [self documentReady:document];
        
    }
    
    [document addObservers];
    
    [[document undoManager] disableUndoRegistration];

    return document;
    
}

+ (void)createDocument:(STMDocument *)document {
    
    [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        
        [self handleHandlerForDocument:document
                               message:@"UIDocumentSaveForCreating"
                               success:success];
        
    }];
    
}

+ (void)openDocument:(STMDocument *)document {
    
    [document openWithCompletionHandler:^(BOOL success) {
        
        [self handleHandlerForDocument:document
                               message:@"openWithCompletionHandler"
                               success:success];
        
    }];
    
}

+ (void)handleHandlerForDocument:(STMDocument *)document message:(NSString *)message success:(BOOL)success {
    
    if (success) {
        
        NSString *logMessage = [NSString stringWithFormat:@"document %@ success", message];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage];
        
        [self documentReady:document];
        
    } else {
        [self documentNotReady:document];
    }
    
}

+ (void)documentReady:(STMDocument *)document {
    
    [[STMLogger sharedLogger] saveLogMessageWithText:NOTIFICATION_DOCUMENT_READY];

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DOCUMENT_READY
                                                        object:document
                                                      userInfo:@{@"uid": document.uid}];
    
}

+ (void)documentNotReady:(STMDocument *)document {
    
    [[STMLogger sharedLogger] saveLogMessageWithText:NOTIFICATION_DOCUMENT_NOT_READY];

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DOCUMENT_NOT_READY
                                                        object:document
                                                      userInfo:@{@"uid": document.uid}];
    
}


@end
