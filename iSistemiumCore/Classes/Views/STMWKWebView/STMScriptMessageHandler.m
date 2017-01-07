//
//  STMScriptMessageHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler.h"

#import "STMCoreObjectsController.h"


@implementation STMScriptMessageHandler

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveFindMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [STMCoreObjectsController arrayOfObjectsRequestedByScriptMessage:message].then(^(NSArray *result){
        
        [webViewVC callbackWithData:result
                         parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [webViewVC callbackWithError:error.localizedDescription
                          parameters:parameters];
        
    });

}

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveUpdateMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [STMCoreObjectsController updateObjectsFromScriptMessage:message withCompletionHandler:^(BOOL success, NSArray *updatedObjects, NSError *error) {
        
        if (success) {
            [webViewVC callbackWithData:updatedObjects parameters:parameters];
        } else {
            [webViewVC callbackWithError:error.localizedDescription parameters:parameters];
        }
        
    }];

}

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveSubscribeMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSLog(@"%@", parameters);
    
    if ([parameters[@"entities"] isKindOfClass:[NSArray class]]) {
        
        webViewVC.subscribeDataCallbackJSFunction = parameters[@"dataCallback"];
        
        NSArray *entities = parameters[@"entities"];
        
        NSError *error = nil;
        
        if ([STMCoreObjectsController subscribeViewController:webViewVC toEntities:entities error:&error]) {
            
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

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveDestroyMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSError *error = nil;
    NSArray *result = [STMCoreObjectsController destroyObjectFromScriptMessage:message error:&error];
    
    if (error) {
        [webViewVC callbackWithError:error.localizedDescription parameters:parameters];
    } else {
        [webViewVC callbackWithData:result parameters:parameters];
    }

}


@end
