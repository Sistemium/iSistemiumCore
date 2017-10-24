//
//  STMScriptMessageHandler+Private.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"
#import "STMScriptMessageHandler+Predicates.h"
#import "STMCoreObjectsController.h"
#import "STMCorePicturesController.h"
#import "STMSessionManager.h"

@implementation STMScriptMessageHandler (Private)

- (void)dealloc {
    // TODO: tests
    NSLogMethodName;
    [self flushSubscribedViewController];
}

#pragma mark - find objects for WKWebView

- (AnyPromise *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage{
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        return [self rejectWithErrorMessage:@"message.body is not a NSDictionary class"];
    }
    
    NSDictionary *parameters = scriptMessage.body;
    NSString *entityName = parameters[@"entity"];

    if (!entityName) {
        return [self rejectWithErrorMessage:@"entity is not specified"];
    }
    
    if (![self.modellingDelegate isConcreteEntityName:entityName]) {
        return [self rejectWithErrorMessage:[entityName stringByAppendingString:@": not found in data model"]];
    }

    if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND]) {
        
        NSString *xidString = parameters[@"id"];
        
        if (!xidString || [xidString isKindOfClass:NSNull.class]) {
            return [self rejectWithErrorMessage:@"empty xid"];
        }
            
        return [self findEntityName:entityName xidString:xidString];
        
    }
    
    NSError *error;
    NSPredicate *predicate = [self predicateForScriptMessage:scriptMessage error:&error];
    
    if (error) return [AnyPromise promiseWithValue:error];
    
    NSDictionary *options = parameters[@"options"];
    
    return [self.persistenceDelegate findAll:entityName
                                   predicate:predicate
                                     options:options];
    
}


#pragma mark - update objects from WKWebView

- (void)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage
                 withCompletionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler {
    
    NSError *resultError = nil;
    
    if (![scriptMessage.body isKindOfClass:NSDictionary.class]) {
        
        [STMFunctions error:&resultError
                withMessage:@"message.body is not a NSDictionary class"];
        
    }
    
    NSDictionary *parameters = scriptMessage.body;
    NSString *entityName = parameters[@"entity"];
    
    if (![self.modellingDelegate isConcreteEntityName:entityName]) {
        
        [STMFunctions error:&resultError
                withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        
    }
    
    id parametersData = parameters[@"data"];
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE]) {
        
        if (![parametersData isKindOfClass:NSDictionary.class]) {
            
            [STMFunctions error:&resultError
                    withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSDictionary class",
                                 scriptMessage.name]];
        } else {
            
            parametersData = @[parametersData];
            
        }
        
    } else if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE_ALL]) {
        
        if (![parametersData isKindOfClass:[NSArray <NSDictionary *> class]]) {
            
            [STMFunctions error:&resultError
                    withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSArray<NSDictionary> class",
                                 scriptMessage.name]];
        }
        
    } else {
        
        [STMFunctions error:&resultError
                withMessage:[NSString stringWithFormat:@"unknown update message name: %@",
                             scriptMessage.name]];
    }
    
    if (resultError) {
        completionHandler(NO, nil, resultError);
        return;
    }
    
    [self.persistenceDelegate mergeMany:entityName
                         attributeArray:parametersData
                                options:nil]
    .then(^(NSArray *updatedObjects){
        completionHandler(YES, updatedObjects, nil);
    })
    .catch(^(NSError *error){
        completionHandler(NO, nil, error);
    });
    
}


#pragma mark - destroy objects from WKWebView

- (AnyPromise *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage{
    
    if (![scriptMessage.body isKindOfClass:NSDictionary.class]) {
        return [self rejectWithErrorMessage:@"message.body is not a NSDictionary class"];
    }
    
    NSDictionary *parameters = scriptMessage.body;
    NSString *entityName = parameters[@"entity"];
    
    if (![self.modellingDelegate isConcreteEntityName:entityName]) {
        return [self rejectWithErrorMessage:[entityName stringByAppendingString:@": not found in data model"]];
    }
    
    NSString *xidString = parameters[@"id"];
    
    if (!xidString) {
        return [self rejectWithErrorMessage:@"empty xid"];
    }
    
    return [self.persistenceDelegate destroy:entityName
                                  identifier:xidString
                                     options:nil]
    .then(^(NSNumber *result){
        return @[@{@"objectXid":xidString}];
    });
    
}

#pragma mark - get pictures from WKWebView

- (void)getPictureSendData:(NSData *)imageData parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
    if (imageData) {
        
        NSString *imageDataBase64String = [imageData base64EncodedStringWithOptions:0];
        [self.owner callbackWithData:@[imageDataBase64String]
                    parameters:parameters
            jsCallbackFunction:jsCallbackFunction];
        
    } else {
        
        [self.owner callbackWithData:@"no image data"
                    parameters:parameters
            jsCallbackFunction:jsCallbackFunction];
        
    }
    
}

- (void)getPictureWithEntityName:(NSString *)entityName withImagePath:(NSString *)imagePath parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
    NSError *error = nil;
    NSString *path = [[STMSessionManager.sharedManager.currentSession.filing picturesBasePath] stringByAppendingPathComponent:imagePath];
    NSData *imageData = [NSData dataWithContentsOfFile:path options:0 error:&error];
    
    if (!imageData) {
        NSString *errorMessage = [NSString stringWithFormat:@"read file error: %@", error.localizedDescription];
        return [self.owner callbackWithError:errorMessage parameters:parameters];
    }
    
    [self getPictureSendData:imageData parameters:parameters jsCallbackFunction:jsCallbackFunction];
    
}

- (void)handleGetPictureParameters:(NSDictionary *)parameters {
    
    NSString *pictureId = parameters[@"id"];
    NSString *callbackFunction = parameters[@"callback"];
    NSString *pictureSize = parameters[@"size"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"attributes.id == %@", pictureId];
    
    NSDictionary *picture = [[STMCorePicturesController.sharedController allPictures] filteredArrayUsingPredicate:predicate].lastObject;
    
    if (!picture) {
        NSString *error = [NSString stringWithFormat:@"no picture with xid %@", pictureId];
        return [self.owner callbackWithError:error parameters:parameters];
    }
    
    NSString *entityName = picture[@"entityName"];
    
    NSDictionary *paths = @{
                            @"thumbnail": @"thumbnailPath",
                            @"resized"  : @"resizedImagePath",
                            @"full"     : @"imagePath"
                            };
    
    NSString *attribute = paths[pictureSize];
    
    if (!attribute) {
        NSString *error = [NSString stringWithFormat:@"unknown size '%@'", pictureSize];
        return [self.owner callbackWithError:error parameters:parameters];
    }
    
    picture = picture[@"attributes"];
    attribute = picture[attribute];
    
    if (![STMFunctions isNotNull:attribute]) {
        return [self downloadPicture:picture withEntityName:entityName parameters:parameters];
    }
    
    [self getPictureWithEntityName:entityName withImagePath:attribute parameters:parameters jsCallbackFunction:callbackFunction];
    
}

- (void)downloadPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName parameters:(NSDictionary *)parameters {
    
    if (![STMFunctions isNotNull:picture[@"href"]]) {
        return [self.owner callbackWithError:@"picture has no imagePath and href" parameters:parameters];
    }
        
    [[STMCorePicturesController sharedController] downloadImagesEntityName:entityName attributes:picture]
    .then(^ (NSDictionary *downloadedPicture){
        [self handleGetPictureParameters:parameters];
    })
    .catch(^ (NSError *error) {
        [self.owner callbackWithError:error.localizedDescription parameters:parameters];
    });

}

#pragma mark - subscribe entities from WKWebView

- (BOOL)subscribeToEntities:(NSArray <NSString *> *)entities callbackName:(NSString *)callbackName error:(NSError **)error {
    
    BOOL result = YES;
    NSString *errorMessage;
    STMScriptMessagingSubscription *subscription = self.subscriptions[callbackName];
    
    if (!subscription) {
        
        subscription = [[STMScriptMessagingSubscription alloc] init];
        subscription.entityNames = [NSMutableSet set];
        subscription.callbackName = callbackName;
        subscription.ltsOffset = @{}.mutableCopy;
        
    }
    
    for (NSString *entityName in entities) {
        
        if ([self.modellingDelegate isConcreteEntityName:entityName]) {
            
            NSString *prfixedEntityName = [STMFunctions addPrefixToEntityName:entityName];
            
            [subscription.entityNames addObject:prfixedEntityName];
            
            [self updateLtsOffsetForEntityName:prfixedEntityName subscription:subscription];
            
        }
        
    }
    
    if (result) {
        
        for (NSString *subscriptionID in subscription.persisterSubscriptions) {
            [self.persistenceDelegate cancelSubscription:subscriptionID];
        }
        
        NSMutableSet *persisterSubscriptions = [NSMutableSet set];
        NSDictionary *options = @{STMPersistingOptionLts:@YES};
        
        for (NSString *entityName in subscription.entityNames) {
            [persisterSubscriptions addObject:[self.persistenceDelegate observeEntity:entityName predicate:nil options:options callback:^(NSArray *data) {
#warning need to check if we're in background
                [self sendSubscribedBunchOfObjects:data entityName:entityName];
            }]];
        }
        
        subscription.persisterSubscriptions = persisterSubscriptions;
        
        self.subscriptions[callbackName] = subscription;
        
    } else {
        
        [STMFunctions error:error withMessage:errorMessage];
        
    }
    
    return result;
    
}

- (void)updateLtsOffsetForEntityName:(NSString *)entityName subscription:(STMScriptMessagingSubscription *)subscription {
    
    NSDictionary *options = @{STMPersistingOptionPageSize   : @1,
                              STMPersistingOptionOrder      : STMPersistingOptionLts,
                              STMPersistingOptionOrderDirectionDesc};
    
    [self.persistenceDelegate findAll:entityName predicate:nil options:options]
    .then(^(NSArray *objects){
        
        if (objects.firstObject) {
            
            [subscription.ltsOffset setObject:objects.firstObject[STMPersistingOptionLts] forKey:entityName];
            
        }
        
    });
    
}

- (void)sendSubscribedBunchOfObjects:(NSArray <NSDictionary *> *)objectsArray entityName:(NSString *)entityName {
    
    NSSet *matchingCallbacks = [self.subscriptions keysOfEntriesPassingTest:^BOOL(NSString * _Nonnull key, STMScriptMessagingSubscription * _Nonnull subscription, BOOL * _Nonnull stop) {
        return [subscription.entityNames containsObject:entityName];
    }];
    
    if (!matchingCallbacks.count) return;
    
    entityName = [STMFunctions removePrefixFromEntityName:entityName];
    
    NSArray *resultArray = [STMFunctions mapArray:objectsArray
                                        withBlock:^id (NSDictionary * object) {
                                            return @{@"entity": entityName,
                                                     @"xid": object[@"id"],
                                                     @"data": object};
                                        }];
    
    for (NSString *callback in matchingCallbacks) {
        [self.owner callbackWithData:resultArray
                          parameters:@{@"reason": @"subscription"}
                  jsCallbackFunction:callback];
    }
    
}

- (void) flushSubscribedViewController {
    
    [self.subscriptions.allValues enumerateObjectsUsingBlock:^(STMScriptMessagingSubscription *subscription, NSUInteger idx, BOOL *stop) {
        [subscription.persisterSubscriptions enumerateObjectsUsingBlock:^(NSString *subscriptionID, BOOL *stop) {
            [self.persistenceDelegate cancelSubscription:subscriptionID];
        }];
    }];
    
    [self.subscriptions removeAllObjects];
    
}


#pragma mark - Private helpers

- (AnyPromise *)rejectWithErrorMessage:(NSString *)errorMessage {
    
    NSError *error;
    
    [STMFunctions error:&error withMessage:errorMessage];
    
    return [AnyPromise promiseWithValue:error];
    
}

- (AnyPromise *)findEntityName:(NSString *)entityName xidString:(NSString *)xidString {
    
    
    return [self.persistenceDelegate find:entityName
                               identifier:xidString
                                  options:nil]
    .then(^(NSDictionary * object){
        
        if (object) {
            return [AnyPromise promiseWithValue:@[object]];
        }
        
        NSString *errorMessage = [NSString stringWithFormat:@"no object with xid %@ and entity name %@", xidString, entityName];
        return [AnyPromise promiseWithValue:[STMFunctions errorWithMessage:errorMessage]];
    
    });
    
}


@end
