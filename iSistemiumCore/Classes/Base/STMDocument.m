//
//  STMDocument.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMDocument.h"
#import "STMCoreObjectsController.h"

#define SAVING_QUEUE_THRESHOLD 15

@interface STMDocument()

@property (nonatomic, strong) NSString *dataModelName;
@property (nonatomic) BOOL saving;
@property (nonatomic) BOOL savingHaveToRepeat;
@property (nonatomic) int savingQueue;

@end


@implementation STMDocument

@synthesize myManagedObjectModel = _myManagedObjectModel;

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

- (void)saveDocument:(void (^)(BOOL success))completionHandler {
    
    if (!self.saving) {
        
        if (self.documentState == UIDocumentStateNormal) {
            
            self.saving = YES;
            
            [self saveToURL:self.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                
                self.saving = NO;
                
                if (success) {
                    
                    NSLog(@"--- documentSavedSuccessfully ---");
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"documentSavedSuccessfully" object:self];
                    
                    completionHandler(YES);
                    
                    if (self.savingHaveToRepeat) {
                        
                        NSLog(@"--- repeat of document saving ---");
                        self.savingHaveToRepeat = NO;
                        
                        [self saveDocument:^(BOOL success) {
                        }];
                        
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
        
    [nc addObserver:self
           selector: @selector(downloadPicture:)
               name:@"downloadPicture"
             object: nil];
    
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
