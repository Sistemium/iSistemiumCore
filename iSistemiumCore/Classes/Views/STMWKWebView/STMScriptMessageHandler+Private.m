//
//  STMScriptMessageHandler+Private.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"
#import "STMScriptMessageHandler+Predicates.h"

@implementation STMScriptMessageHandler (Private)

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
        
        if (!xidString) {
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
    NSString *entityName = [NSString stringWithFormat:@"%@%@",
                            ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
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


#pragma mark - subscribe entities from WKWebView

- (BOOL)subscribeToEntities:(NSArray <NSString *> *)entities callbackName:(NSString *)callbackName error:(NSError **)error {
    
    BOOL result = YES;
    NSString *errorMessage;
    STMScriptMessagingSubscription *subscription = self.subscriptions[callbackName];
    
    if (!subscription) {
        subscription = [[STMScriptMessagingSubscription alloc] init];
        subscription.entityNames = [NSMutableSet set];
        subscription.callbackName = callbackName;
    }
    
    for (NSString *item in entities) {
        
        NSString *entityName = [STMFunctions addPrefixToEntityName:item];
        
        if ([self.modellingDelegate isConcreteEntityName:entityName]) {
            
            [subscription.entityNames addObject:entityName];
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"entity name %@ is not in local data model",
                            entityName];
            result = NO;
            break;
            
        }
        
    }
    
    if (result) {
        
        self.subscriptions[callbackName] = subscription;
        
    } else {
        
        [STMFunctions error:error withMessage:errorMessage];
        
    }
    
    return result;
    
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
