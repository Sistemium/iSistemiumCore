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

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {
    
    __block NSString *errorMessage = [self preFindAsyncCheckForEntityName:entityName
                                                       identifier:identifier];
    
    if (errorMessage) {
        [self completeWithErrorMessage:errorMessage dictionaryHandler:completionHandler];
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
                
                [self completeWithErrorMessage:@"ERROR: response contain no dictionary"
                             dictionaryHandler:completionHandler];
                return;
                
            }
            
            if (response[@"error"]) {
                
                errorMessage = [NSString stringWithFormat:@"response got error: %@", response[@"error"]];
                
                [self completeWithErrorMessage:errorMessage dictionaryHandler:completionHandler];
                return;
                
            }
            
            completionHandler(YES, response, nil, nil);
            
        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncArrayResultCallback)completionHandler {
    
    __block NSString *errorMessage = [self preFindAllAsyncCheckForEntityName:entityName];
    
    if (errorMessage) {
        
        [self completeWithErrorMessage:errorMessage
                          arrayHandler:completionHandler];
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
                
                [self completeWithErrorMessage:@"ERROR: response contain no dictionary"
                                  arrayHandler:completionHandler];
                return;
                
            }
            
            NSNumber *errorCode = response[@"error"];
            
            if (errorCode) {
                
                errorMessage = [NSString stringWithFormat:@"    %@: ERROR: %@", entityName, errorCode];
                
                [self completeWithErrorMessage:errorMessage
                                  arrayHandler:completionHandler];
                return;
                
            }
            
            NSArray *responseData = ([response[@"data"] isKindOfClass:[NSArray class]]) ? response[@"data"] : nil;
            
            if (!responseData) {
                
                errorMessage = [NSString stringWithFormat:@"    %@: ERROR: find all response data is not an array", entityName];
                
                [self completeWithErrorMessage:errorMessage
                             arrayHandler:completionHandler];
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

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {
    
    if (!self.isReady) {
        
        [self completeWithErrorMessage:@"socket is not ready (not connected or not authorized)"
                     dictionaryHandler:completionHandler];
        
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    NSString *resource = [entity resource];
    
    if (!resource) {
        
        [self completeWithErrorMessage:[NSString stringWithFormat:@"no url for entity %@", entityName]
                     dictionaryHandler:completionHandler];
        
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
                
                [self completeWithErrorMessage:@"ERROR: response contain no dictionary"
                             dictionaryHandler:completionHandler];
                return;
                
            }
            
            completionHandler(YES, response, nil, nil);
            
        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

#pragma mark - validations

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

#pragma mark - error handlers

- (void)completeWithErrorMessage:(NSString *)errorMessage dictionaryHandler:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler  {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}


- (void)completeWithErrorMessage:(NSString *)errorMessage arrayHandler:(STMPersistingWithHeadersAsyncArrayResultCallback)completionHandler {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}

@end
