//
//  STMSocketTransport+Persisting.m
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport+Persisting.h"
#import "STMSocketTransport+Decoder.h"

@implementation STMSocketTransport (Persisting)

#pragma mark - STMPersistingWithHeadersAsync

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];

    NSString *errorMessage = [self preFindAsyncCheckForEntityName:entityName
                                                       identifier:identifier];

    if (errorMessage) {
        [self completeWithErrorMessage:errorMessage dictionaryHandler:completionHandler];
        return;
    }

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    NSDictionary *value = @{@"method": kSocketFindMethod,
            @"resource": resource,
            @"id": identifier};

    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {

        if (!success) {
            return completionHandler(NO, nil, nil, error);
        }

        [self respondOnData:data dictionaryHandler:completionHandler];

    }];

}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncArrayResultCallback)completionHandler {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];

    NSString *errorMessage = [self preFindAllAsyncCheckForEntityName:entityName];

    if (errorMessage) {

        [self completeWithErrorMessage:errorMessage
                          arrayHandler:completionHandler];
        return;

    }

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    NSMutableDictionary *value = @{@"method": kSocketFindAllMethod,
                                   @"resource": resource,
                                   @"options": options
                                   }.mutableCopy;
    
    if ([STMFunctions isNotNull:options] && [options.allKeys containsObject:@"params"]){
        
        value[@"params"] = options[@"params"];
        
    }

    [self socketSendEvent:STMSocketEventJSData withValue:value.copy completionHandler:^(BOOL success, NSArray *data, NSError *error) {

        if (!success) {
            return completionHandler(NO, nil, nil, error);
        }

        [self respondOnData:data arrayHandler:completionHandler];

    }];

}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    if (!resource) {
        return [self completeWithErrorMessage:[NSString stringWithFormat:@"no url for entity %@", entityName]
                            dictionaryHandler:completionHandler];
    }

    NSDictionary *value = @{@"method": kSocketUpdateMethod,
            @"resource": resource,
            @"id": STMIsNull(attributes[@"id"], [STMFunctions uuidString]),
            @"attrs": attributes};

    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {

        if (!success) {
            return completionHandler(NO, nil, nil, error);
        }

        [self respondOnData:data dictionaryHandler:completionHandler];

    }];

}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options
   completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    NSDictionary *value = @{@"method": kSocketDestroyMethod,
                            @"resource": resource,
                            @"id": identifier};

    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {

        if (!success) {
            return completionHandler(NO, nil, nil, error);
        }

        STSocketsJSDataResponse *decoded = [self STSocketsJSDataResponseFromSocketIO:data];
        
        if ([decoded isKindOfClass:STSocketsJSDataResponseError.class]) {
            
            STSocketsJSDataResponseError *errorResponse = (STSocketsJSDataResponseError *) decoded;
            [STMFunctions error:&error withMessage:errorResponse.errorText];
            completionHandler(NO, nil, errorResponse.headers, error);
            
        } else {
            
            STSocketsJSDataResponseSuccessObject *response = (STSocketsJSDataResponseSuccessObject *) decoded;
            completionHandler(YES, response.data, response.headers, nil);
            
        }

    }];
    
}


#pragma mark - Responders

- (void)respondOnData:(NSArray *)data dictionaryHandler:(STMPersistingWithHeadersAsyncDictionaryResultCallback)handler {

    STSocketsJSDataResponse *decoded = [self STSocketsJSDataResponseFromSocketIO:data];
    NSError *error;

    if ([decoded isKindOfClass:STSocketsJSDataResponseError.class]) {

        STSocketsJSDataResponseError *errorResponse = (STSocketsJSDataResponseError *) decoded;
        [STMFunctions error:&error withMessage:errorResponse.errorText];
        handler(NO, nil, errorResponse.headers, error);

    } else if (![decoded isKindOfClass:STSocketsJSDataResponseSuccessObject.class]) {

        [STMFunctions error:&error withMessage:@"response is not a dictionary"];
        handler(NO, nil, decoded.headers, error);

    } else {

        STSocketsJSDataResponseSuccessObject *response = (STSocketsJSDataResponseSuccessObject *) decoded;
        handler(YES, response.data, response.headers, nil);

    }

}

- (void)respondOnData:(NSArray *)data arrayHandler:(STMPersistingWithHeadersAsyncArrayResultCallback)handler {

    STSocketsJSDataResponse *decoded = [self STSocketsJSDataResponseFromSocketIO:data];
    NSError *error;

    if ([decoded isKindOfClass:STSocketsJSDataResponseError.class]) {

        STSocketsJSDataResponseError *errorResponse = (STSocketsJSDataResponseError *) decoded;
        [STMFunctions error:&error withMessage:errorResponse.errorText];
        handler(NO, nil, errorResponse.headers, error);

    } else if (![decoded isKindOfClass:STSocketsJSDataResponseSuccessArray.class]) {

        [STMFunctions error:&error withMessage:@"response is not an array"];
        handler(NO, nil, decoded.headers, error);

    } else {

        STSocketsJSDataResponseSuccessArray *response = (STSocketsJSDataResponseSuccessArray *) decoded;
        handler(YES, response.data, response.headers, nil);

    }

}

#pragma mark - validations

- (NSString *)preFindAsyncCheckForEntityName:(NSString *)entityName identifier:(NSString *)identifier {

    if (!self.isReady) {
        return @"socket is not ready (not connected or not authorized)";
    }

    NSDictionary *entity = [STMEntityController stcEntities][entityName];

    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    if (!resource) {
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

    NSDictionary *entity = [STMEntityController stcEntities][entityName];

    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }

    NSString *resource = [STMEntityController resourceForEntity:entityName];

    if (!resource) {
        return [NSString stringWithFormat:@"no resource for entity %@", entityName];
    }

    return nil;

}

#pragma mark - error handlers

- (void)completeWithErrorMessage:(NSString *)errorMessage dictionaryHandler:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler {

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
