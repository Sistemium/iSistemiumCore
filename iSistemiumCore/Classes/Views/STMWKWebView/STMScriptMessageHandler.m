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
    _modellingDelegate = persistenceDelegate;
    
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
    
    if ([parameters[@"entities"] isKindOfClass:[NSArray class]]) {
        
        NSArray *entities = parameters[@"entities"];
        NSString *dataCallback = parameters[@"dataCallback"];
        NSError *error = nil;
        
        if ([self subscribeToEntities:entities callbackName:dataCallback error:&error]) {
            
            [self.owner callbackWithData:@[@"subscribe to entities success"]
                              parameters:parameters
                      jsCallbackFunction:parameters[@"callback"]];
            
        } else {
            
            [self.owner callbackWithError:error.localizedDescription
                               parameters:parameters];
            
        }
        
    } else {
        
        [self.owner callbackWithError:@"message.parameters.entities is not a NSArray class"
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
