//
//  STMCoreApplication.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreApplication.h"


@implementation STMCoreApplication

+(STMCoreApplication *) sharedApplication{
    static dispatch_once_t pred = 0;
    __strong static id _sharedApp = nil;
    
    dispatch_once(&pred, ^{
        _sharedApp = [UIApplication sharedApplication];
    });
    return _sharedApp;
}

-(BOOL)isNetworkActivityIndicatorVisible{
    if (_states){
        return self.states.networkActivityIndicatorVisible;
    }
    
    return super.networkActivityIndicatorVisible;
}

-(void) setNetworkActivityIndicatorVisible:(BOOL)networkActivityIndicatorVisible{
    if (_states){
        [self.states setNetworkActivityIndicatorVisible:networkActivityIndicatorVisible];
    }else{
        [super setNetworkActivityIndicatorVisible:networkActivityIndicatorVisible];
    }
    
}

@end
