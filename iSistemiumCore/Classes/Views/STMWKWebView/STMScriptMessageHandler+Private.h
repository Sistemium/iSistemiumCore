//
//  STMScriptMessageHandler+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler.h"

@interface STMScriptMessageHandler (Private)

- (AnyPromise *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage;

- (void)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage
                 withCompletionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler;

- (AnyPromise *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage;

- (void)handleGetPictureParameters:(NSDictionary *)parameters;

- (BOOL)subscribeToEntities:(NSArray <NSString *> *)entities
               callbackName:(NSString *)callbackName
                      error:(NSError **)error;

- (void)sendSubscribedBunchOfObjects:(NSArray <NSDictionary *> *)objectsArray entityName:(NSString *)entityName;

- (void)updateLtsOffsetForEntityName:(NSString *)entityName subscription:(STMScriptMessagingSubscription *)subscription;

- (void) flushSubscribedViewController;

@end
