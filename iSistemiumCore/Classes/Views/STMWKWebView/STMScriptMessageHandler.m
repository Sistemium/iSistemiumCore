//
//  STMScriptMessageHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"
#import "STMSessionManager.h"

@implementation STMScriptMessageHandler

- (NSMutableDictionary *)entitiesToSubscribe {
    if (!_entitiesToSubscribe) {
        _entitiesToSubscribe = @{}.mutableCopy;
    }
    return _entitiesToSubscribe;
}

-(id)persistenceDelegate {
    if (!_persistenceDelegate) {
        _persistenceDelegate = STMCoreSessionManager.sharedManager.currentSession.persistenceDelegate;
    }
    return _persistenceDelegate;
}

- (NSMutableArray *)subscribedObjects {
    
    if (!_subscribedObjects) {
        _subscribedObjects = @[].mutableCopy;
    }
    return _subscribedObjects;
    
}

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveFindMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self arrayOfObjectsRequestedByScriptMessage:message].then(^(NSArray *result){
        
        [webViewVC callbackWithData:result
                         parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [webViewVC callbackWithError:error.localizedDescription
                          parameters:parameters];
        
    });

}

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveUpdateMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self updateObjectsFromScriptMessage:message withCompletionHandler:^(BOOL success, NSArray *updatedObjects, NSError *error) {
        
        if (success) {
            [webViewVC callbackWithData:updatedObjects parameters:parameters];
        } else {
            [webViewVC callbackWithError:error.localizedDescription parameters:parameters];
        }
        
    }];

}

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveSubscribeMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSLog(@"%@", parameters);
    
    if ([parameters[@"entities"] isKindOfClass:[NSArray class]]) {
        
        webViewVC.subscribeDataCallbackJSFunction = parameters[@"dataCallback"];
        
        NSArray *entities = parameters[@"entities"];
        
        NSError *error = nil;
        
        if ([self subscribeViewController:webViewVC toEntities:entities error:&error]) {
            
            [webViewVC callbackWithData:@[@"subscribe to entities success"]
                             parameters:parameters
                     jsCallbackFunction:parameters[@"callback"]];
            
        } else {
            
            [webViewVC callbackWithError:error.localizedDescription
                         parameters:parameters];
            
        }
        
    } else {
        
        [webViewVC callbackWithError:@"message.parameters.entities is not a NSArray class"
                     parameters:parameters];
        
    }
    
}

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveDestroyMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self destroyObjectFromScriptMessage:message].then(^(NSArray *result){
        
        [webViewVC callbackWithData:result parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [webViewVC callbackWithError:error.localizedDescription parameters:parameters];
        
    });

}

- (void)unsubscribeViewController:(UIViewController *)vc {

    NSLog(@"unsubscribeViewController: %@", vc);
    [self flushSubscribedViewController:vc];
    
}

@end
