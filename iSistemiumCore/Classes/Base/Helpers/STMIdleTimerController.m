//
//  STMIdleTimerController.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 23/09/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIdleTimerController.h"
#import <UIKit/UIKit.h>


@interface STMIdleTimerController ()

@property (nonatomic, strong) NSMutableDictionary *applicants;


@end


@implementation STMIdleTimerController

- (NSMutableDictionary *)applicants {
    
    if (!_applicants) {
        _applicants = @{}.mutableCopy;
    }
    return _applicants;
    
}

+ (instancetype)sharedIdleTimerController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

+ (void)sender:(NSString *)senderName askIdleTimerDisabled:(BOOL)disabled {
    
    NSLog(@"%@ %@", senderName, @(disabled));
    
    disabled ? [self disableBySender:senderName] : [self enableBySender:senderName];
    
}

+ (void)disableBySender:(NSString *)senderName {

    @synchronized (senderName) {
        
        STMIdleTimerController *itc = [self sharedIdleTimerController];
        
        NSNumber *senderCount = itc.applicants[senderName];
        senderCount = senderCount ? @(senderCount.integerValue + 1) : @(1);
        
        itc.applicants[senderName] = senderCount;
        
        NSLog(@"%@ ask for idleTimerDisabled", senderName);

        [UIApplication sharedApplication].idleTimerDisabled = YES;

    }
    
}

+ (void)enableBySender:(NSString *)senderName {
    
    @synchronized (senderName) {
        
        STMIdleTimerController *itc = [self sharedIdleTimerController];
        
        NSNumber *senderCount = itc.applicants[senderName];
        senderCount = senderCount ? @(senderCount.integerValue - 1) : @(0);
        
        if (!senderCount.integerValue) {
            [itc.applicants removeObjectForKey:senderName];
        }
        
        NSLog(@"%@ ask for idleTimerEnabled", senderName);

        NSNumber *totalCount = [itc.applicants.allValues valueForKeyPath:@"@sum.self"];
        
        if (!totalCount.integerValue) {
            
            NSLog(@"no more applicants, enable idleTimer");
            [UIApplication sharedApplication].idleTimerDisabled = NO;
            
        } else {
            NSLog(@"%@ more applicants, defer enable idleTimer", totalCount);
        }
        
    }

}


@end
