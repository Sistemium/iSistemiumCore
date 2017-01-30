//
//  STMScriptMessageHandler+Private.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"
#import "STMScriptMessagesController.h"

@implementation STMScriptMessageHandler (Private)

#pragma mark - find objects for WKWebView

- (AnyPromise *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage{
    
    NSError* error = nil;
    
    NSArray *result = nil;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&error
                withMessage:@"message.body is not a NSDictionary class"];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    NSDictionary *parameters = scriptMessage.body;
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND]) {
        
        result = [self findObjectWithParameters:parameters
                                          error:&error];
        if (error) {
            return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
                resolve(error);
            }];
        }
        
        if (result) {
            return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
                resolve(result);
            }];
            
        }
        
    }
    
    NSLog(@"find %@", @([NSDate timeIntervalSinceReferenceDate]));
    
    if (error) {
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
    }
    
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    NSDictionary *options = parameters[@"options"];
    
    NSPredicate *predicate = [STMScriptMessagesController
                              predicateForScriptMessage:scriptMessage
                              error:&error];
    
    return [self.persistenceDelegate
            findAll:entityName
            predicate:predicate
            options:options];
    
}


#pragma mark - update objects from WKWebView

- (void)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage
                 withCompletionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler {
    
    NSError *resultError = nil;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&resultError
                withMessage:@"message.body is not a NSDictionary class"];
        completionHandler(NO, nil, resultError);
        return;
        
    }
    
    NSDictionary *parameters = scriptMessage.body;
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![self.persistenceDelegate isConcreteEntityName:entityName]) {
        
        [STMFunctions error:&resultError
                withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        completionHandler(NO, nil, resultError);
        return;
        
    }
    
    id parametersData = parameters[@"data"];
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE]) {
        
        if (![parametersData isKindOfClass:[NSDictionary class]]) {
            
            [STMFunctions error:&resultError
                    withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSDictionary class", scriptMessage.name]];
            completionHandler(NO, nil, resultError);
            return;
            
        } else {
            
            parametersData = @[parametersData];
            
        }
        
    } else if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE_ALL]) {
        
        if (![parametersData isKindOfClass:[NSArray <NSDictionary *> class]]) {
            
            [STMFunctions error:&resultError
                    withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSArray<NSDictionary> class", scriptMessage.name]];
            completionHandler(NO, nil, resultError);
            return;
            
        }
        
    } else {
        
        [STMFunctions error:&resultError
                withMessage:[NSString stringWithFormat:@"unknown update message name: %@", scriptMessage.name]];
        completionHandler(NO, nil, resultError);
        return;
        
    }
    
    [self handleUpdateMessageData:parametersData
                       entityName:entityName
                completionHandler:completionHandler];
    
}

- (void)handleUpdateMessageData:(NSArray *)data entityName:(NSString *)entityName
              completionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler{
    
    NSError *localError = nil;
    
    NSArray *results = [self.persistenceDelegate
                        mergeManySync:entityName
                        attributeArray:data
                        options:nil
                        error:&localError];
    
    if (localError) {
        
        completionHandler(NO, nil, localError);
        
    } else {
        
        // Assuming there's no CoreData
        completionHandler(YES, results, localError);
        
    }
    
}


#pragma mark - destroy objects from WKWebView

- (AnyPromise *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage{
    
    NSError* error;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&error withMessage:@"message.body is not a NSDictionary class"];
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    NSDictionary *parameters = scriptMessage.body;
    
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![self.persistenceDelegate isConcreteEntityName:entityName]) {
        
        [STMFunctions error:&error withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    NSString *xidString = parameters[@"id"];
    
    if (!xidString) {
        
        [STMFunctions error:&error withMessage:@"empty xid"];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    return [[self persistenceDelegate] destroy:entityName identifier:xidString options:nil].then(^(NSNumber *result){
        return @[@{@"objectXid":xidString}];
    });
    
}


#pragma mark - subscribe entities from WKWebView

- (BOOL)subscribeViewController:(UIViewController <STMEntitiesSubscribable> *)vc toEntities:(NSArray *)entities error:(NSError **)error {
    
    BOOL result = YES;
    NSString *errorMessage;
    NSMutableArray *entitiesToSubscribe = @[].mutableCopy;
    
    for (id item in entities) {
        
        if ([item isKindOfClass:[NSString class]]) {
            
            NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, item];
            
            if ([self.persistenceDelegate isConcreteEntityName:entityName]) {
                
                [entitiesToSubscribe addObject:entityName];
                
            } else {
                
                errorMessage = [NSString stringWithFormat:@"entity name %@ is not in local data model", entityName];
                result = NO;
                break;
                
            }
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"entities array item %@ is not a NSString", item];
            result = NO;
            break;
            
        }
        
    }
    
    if (result) {
        
        NSLog(@"subscribeViewController: %@ toEntities: %@", vc, entitiesToSubscribe);
        
        [self flushSubscribedViewController:vc];
        
        for (NSString *entityName in entitiesToSubscribe) {
            
            NSArray *vcArray = self.entitiesToSubscribe[entityName];
            
            if (vcArray) {
                if (![vcArray containsObject:vc]) {
                    vcArray = [vcArray arrayByAddingObject:vc];
                }
            } else {
                vcArray = @[vc];
            }
            
            self.entitiesToSubscribe[entityName] = vcArray;
            
        }
        
    } else {
        
        [STMFunctions error:error withMessage:errorMessage];
        
    }
    
    return result;
    
}

- (void)sendSubscribedBunchOfObjects:(NSArray *)objectArray entityName:(NSString *)entityName {
    
    NSArray <UIViewController <STMEntitiesSubscribable> *> *vcArray = self.entitiesToSubscribe[entityName];
    
    if (vcArray.count > 0) {
        
        entityName = [STMFunctions removePrefixFromEntityName:entityName];
        
        NSMutableArray *resultArray = @[].mutableCopy;
        
        for (STMDatum *object in objectArray) {
            
            if (object.id) {
                
                NSDictionary *subscribeDic = @{@"entity"    : entityName,
                                               @"xid"       : [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid],
                                               @"data"      : object};
                
                [resultArray addObject:subscribeDic];
                
            }
            
        }
        
        for (UIViewController <STMEntitiesSubscribable> *vc in vcArray) {
            [vc subscribedObjectsArrayWasReceived:resultArray];
        }
        
    }
    
}

- (void) flushSubscribedViewController:(id)vc {
    for (NSString *entityName in self.entitiesToSubscribe.allKeys) {
        
        NSMutableArray *vcArray = self.entitiesToSubscribe[entityName].mutableCopy;
        
        [vcArray removeObject:vc];
        
        self.entitiesToSubscribe[entityName] = vcArray;
        
    }
    
}


#pragma mark - Private helpers

- (NSArray *)findObjectWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    
    NSString *errorMessage = nil;
    
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if ([self.persistenceDelegate isConcreteEntityName:entityName]) {
        
        NSString *xidString = parameters[@"id"];
        
        if (xidString) {
            
            NSDictionary* object = [self.persistenceDelegate findSync:entityName
                                                           identifier:xidString
                                                              options:nil
                                                                error:error];
            
            if (object) {
                return @[object];
            }
            
            errorMessage = [NSString stringWithFormat:@"no object with xid %@ and entity name %@", xidString, entityName];
            
        } else {
            errorMessage = @"empty xid";
        }
        
    } else {
        errorMessage = [entityName stringByAppendingString:@": not found in data model"];
    }
    
    if (errorMessage) {
        [STMFunctions error:error
                withMessage:errorMessage];
    }
    
    return nil;
    
}


@end
