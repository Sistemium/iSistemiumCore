//
//  STMScriptMessageHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"

@implementation STMScriptMessagingSubscription

@end

@implementation STMScriptMessageHandler

- (instancetype)initWithOwner:(id <STMScriptMessagingOwner>)owner{
    id result = [self init];
    self.owner = owner;
    _subscriptions = [NSMutableDictionary dictionary];
    _getPictureCallbackJSFunctions = @{}.mutableCopy;
    _getPictureMessageParameters = @{}.mutableCopy;
    return result;
}

- (NSMutableArray *)subscribedObjects {
    
    if (!_subscribedObjects) {
        _subscribedObjects = @[].mutableCopy;
    }
    return _subscribedObjects;
    
}

- (void)setPersistenceDelegate:(id)persistenceDelegate {
    
    _persistenceDelegate = persistenceDelegate;
    
    if ([persistenceDelegate conformsToProtocol:@protocol(STMModelling)]) {
        _modellingDelegate = persistenceDelegate;
    }
    
}

- (void)handleGetPictureMessage:(WKScriptMessage *)message {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSDictionary *parameters = message.body;
        [self handleGetPictureParameters:parameters];
        
    });
    
}

- (void)receiveFindMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self arrayOfObjectsRequestedByScriptMessage:message].then(^(NSArray *result){
        
        [self.owner callbackWithData:result
                          parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    });
    
}

- (void)receiveUpdateMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self updateObjectsFromScriptMessage:message
                   withCompletionHandler:^(BOOL success, NSArray *updatedObjects, NSError *error) {
        
        if (success) {
            [self.owner callbackWithData:updatedObjects
                              parameters:parameters];
        } else {
            [self.owner callbackWithError:error.localizedDescription
                               parameters:parameters];
        }
        
    }];
    
}

- (void)receiveSubscribeMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSLog(@"receiveSubscribeMessage: %@", parameters);
    
    NSArray *entities = parameters[@"entities"];
    
    if (![entities isKindOfClass:NSArray.class]) {
        [self.owner callbackWithError:@"message.parameters.entities is not a NSArray class"
                           parameters:parameters];
    }
    
    NSString *errorMessage;

    NSString *dataCallback = parameters[@"dataCallback"];
    NSString *callback = parameters[@"callback"];
    
    if (!dataCallback) {
        errorMessage = @"No dataCallback specified";
    } else if (!callback) {
        errorMessage = @"No callback specified";
    }
    
    if (errorMessage) {
        return [self.owner callbackWithError:errorMessage parameters:parameters];
    }
    
    NSError *error = nil;
    
    if ([self subscribeToEntities:entities callbackName:dataCallback error:&error]) {
        
        [self.owner callbackWithData:@[@"subscribe to entities success"]
                          parameters:parameters
                  jsCallbackFunction:callback];
        
    } else {
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    }
    
}

- (void)receiveDestroyMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self destroyObjectFromScriptMessage:message].then(^(NSArray *result){
        
        [self.owner callbackWithData:result
                          parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    });
    
}

- (void)cancelSubscriptions {
    
    NSLog(@"unsubscribeViewController: %@", self.owner);
    [self flushSubscribedViewController];
    
}

@end
