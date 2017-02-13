//
//  STMScriptMessaging.h
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

typedef NSDictionary <NSString *, __kindof NSObject *> STMScriptMessagingFilterDictionary;
typedef NSDictionary <NSString *, STMScriptMessagingFilterDictionary *> STMScriptMessagingWhereFilterDictionary;

@protocol STMScriptMessagingOwner

- (void)callbackWithError:(NSString *)errorDescription
               parameters:(NSDictionary *)parameters;

- (void)callbackWithData:(NSArray *)data
              parameters:(NSDictionary *)parameters;

- (void)callbackWithData:(id)data
              parameters:(NSDictionary *)parameters
      jsCallbackFunction:(NSString *)jsCallbackFunction;

@end

@protocol STMScriptMessaging

- (id <STMScriptMessaging>)initWithOwner:(id <STMScriptMessagingOwner>)owner;

- (void)handleGetPictureMessage:(WKScriptMessage *)message;

- (void)receiveFindMessage:(WKScriptMessage *)message;

- (void)receiveUpdateMessage:(WKScriptMessage *)message;

- (void)receiveDestroyMessage:(WKScriptMessage *)message;

- (void)receiveSubscribeMessage:(WKScriptMessage *)message;

- (void)cancelSubscriptions;

@end
