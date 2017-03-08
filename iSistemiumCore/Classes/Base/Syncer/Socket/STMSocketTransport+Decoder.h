//
//  STMSocketTransport+Decoder.h
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport.h"

@interface STSocketsJSDataResponse : NSObject
@property NSDictionary *headers;
@end


@interface STSocketsJSDataResponseError : STSocketsJSDataResponse
@property NSUInteger errorCode;
@property NSString *errorText;
@end

@interface STSocketsJSDataResponseSuccess : STSocketsJSDataResponse
@end

@interface STSocketsJSDataResponseSuccessObject : STSocketsJSDataResponseSuccess
@property NSDictionary *data;
@end

@interface STSocketsJSDataResponseSuccessArray : STSocketsJSDataResponseSuccess
@property NSArray *data;
@end

@interface STMSocketTransport (Decoder)

- (STSocketsJSDataResponse *)STSocketsJSDataResponseFromSocketIO:(NSArray *)socketIOResponse;

@end
