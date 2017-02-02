//
//  STMSocketTransport+Persisting.m
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport+Persisting.h"

@implementation STMSocketTransport (Persisting)

#pragma mark - STMPersistingWithHeadersAsync
#pragma mark find

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler {
    
    NSString *errorMessage = [self preFindAsyncCheckForEntityName:entityName
                                                       identifier:identifier];
    
    if (errorMessage) {
        
        [self completeFindAsyncHandler:completionHandler
                      withErrorMessage:errorMessage];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    NSString *resource = [entity resource];
    
    NSDictionary *value = @{@"method"   : kSocketFindMethod,
                            @"resource" : resource,
                            @"id"       : identifier};
    
    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
            
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
            
            if (!response) {
                
                [self completeFindAsyncHandler:completionHandler
                              withErrorMessage:@"ERROR: response contain no dictionary"];
                return;
                
            }
            
            if (response[@"error"]) {
                
                [self completeFindAsyncHandler:completionHandler
                              withErrorMessage:[NSString stringWithFormat:@"response got error: %@", response[@"error"]]];
                return;
                
            }
            
            completionHandler(YES, response, nil, nil);
            
        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (NSString *)preFindAsyncCheckForEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    
    if (!self.isReady) {
        return @"socket is not ready (not connected or not authorize)";
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }
    
    if (![entity resource]) {
        return [NSString stringWithFormat:@"no resource for entity %@", entityName];
    }
    
    if (!identifier) {
        return [NSString stringWithFormat:@"no identifier for findAsync: %@", entityName];
    }
    
    return nil;
    
}

- (void)completeFindAsyncHandler:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}

#pragma mark findAll

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error))completionHandler {
    
    NSString *errorMessage = [self preFindAllAsyncCheckForEntityName:entityName];
    
    if (errorMessage) {
        
        [self completeFindAllAsyncHandler:completionHandler
                         withErrorMessage:errorMessage];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    NSString *resource = [entity resource];
    
    NSDictionary *value = @{@"method"   : kSocketFindAllMethod,
                            @"resource" : resource,
                            @"options"  : options
                            };
    
    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
            
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
            
            if (!response) {
                
                [self completeFindAllAsyncHandler:completionHandler
                                 withErrorMessage:@"ERROR: response contain no dictionary"];
                return;
                
            }
            
            NSNumber *errorCode = response[@"error"];
            
            if (errorCode) {
                
                [self completeFindAllAsyncHandler:completionHandler
                                 withErrorMessage:[NSString stringWithFormat:@"    %@: ERROR: %@", entityName, errorCode]];
                return;
                
            }
            
            NSArray *responseData = ([response[@"data"] isKindOfClass:[NSArray class]]) ? response[@"data"] : nil;
            
            if (!responseData) {
                
                [self completeFindAllAsyncHandler:completionHandler
                                 withErrorMessage:[NSString stringWithFormat:@"    %@: ERROR: find all response data is not an array", entityName]];
                return;
                
            }
            
            NSMutableDictionary *headers = @{}.mutableCopy;
            
            [response enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                
                if (![key isEqualToString:@"data"]) {
                    headers[key] = obj;
                }
                
            }];
            
            completionHandler(YES, responseData, headers, nil);
            
        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (NSString *)preFindAllAsyncCheckForEntityName:(NSString *)entityName {
    
    if (!self.isReady) {
        return @"socket is not ready (not connected or not authorized)";
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }
    
    if (![entity resource]) {
        return [NSString stringWithFormat:@"no resource for entity %@", entityName];
    }
    
    return nil;
    
}

- (void)completeFindAllAsyncHandler:(void (^)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}

#pragma mark merge

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler {
    
    if (!self.isReady) {
        
        [self completeMergeAsyncHandler:completionHandler
                       withErrorMessage:@"socket is not ready (not connected or not authorize)"];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    NSString *resource = [entity resource];
    
    if (!resource) {
        
        [self completeMergeAsyncHandler:completionHandler
                       withErrorMessage:[NSString stringWithFormat:@"no url for entity %@", entityName]];
        return;
        
    }
    
    
    NSDictionary *value = @{@"method"   : kSocketUpdateMethod,
                            @"resource" : resource,
                            @"id"       : attributes[@"id"],
                            @"attrs"    : attributes};
    
    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
            
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
            
            if (!response) {
                
                [self completeMergeAsyncHandler:completionHandler
                               withErrorMessage:@"ERROR: response contain no dictionary"];
                return;
                
            }
            
            completionHandler(YES, response, nil, nil);
            
        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (void)completeMergeAsyncHandler:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}


@end
