//
//  STMSocketTransport+Decoder.m
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport+Decoder.h"


@implementation STMSocketTransport (Decoder)

- (STSocketsJSDataResponse *)STSocketsJSDataResponseFromSocketIO:(NSArray *)socketIOResponse {
   
    if (socketIOResponse.count != 1) {
        STSocketsJSDataResponseError *error = [[STSocketsJSDataResponseError alloc] init];
        error.errorCode = 0;
        error.errorText = @"Response length is not 1";
        error.headers = @{@"rawResponse": socketIOResponse};
        return error;
    }
    
    NSDictionary *stResponse = socketIOResponse.firstObject;
    STSocketsJSDataResponse *response;
    
    id data = stResponse[@"data"];
    
    if ([[data class] isSubclassOfClass:NSDictionary.class]) {
        response = [[STSocketsJSDataResponseSuccessObject alloc] init];
        [(STSocketsJSDataResponseSuccessObject *)response setData:data];
    } else if ([[data class] isSubclassOfClass:NSArray.class]) {
        response = [[STSocketsJSDataResponseSuccessArray alloc] init];
        [(STSocketsJSDataResponseSuccessObject *)response setData:data];
    } else {
        STSocketsJSDataResponseError *error = [[STSocketsJSDataResponseError alloc] init];
        
        error.errorCode = [stResponse[@"error"] integerValue];
        
        if ([[stResponse[@"text"] class] isSubclassOfClass:NSDictionary.class]) {
            error.errorText = stResponse[@"text"][@"text"];
        } else {
            error.errorText = stResponse[@"text"];
        }
        
        if (!error.errorText) {
            error.errorText = @"Unknown error";
        }
        
        if (!error.errorCode) error.errorCode = 500;
        
        response = error;
    }
    
    NSMutableDictionary *headers = [(NSDictionary *)stResponse mutableCopy];
    
    [headers removeObjectForKey:@"data"];
    response.headers = headers.copy;

    return response;
    
}

@end


@implementation STSocketsJSDataResponse
@end

@implementation STSocketsJSDataResponseError
@end

@implementation STSocketsJSDataResponseSuccess
@end

@implementation STSocketsJSDataResponseSuccessObject
@end

@implementation STSocketsJSDataResponseSuccessArray
@end
