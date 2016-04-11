//
//  STMLogMessage.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMLogMessage.h"

#import "STMFunctions.h"


@implementation STMLogMessage

- (NSString *)dayAsString {
    
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        formatter = [STMFunctions dateNumbersFormatter];
    });
    
    return (self.deviceCts) ? [formatter stringFromDate:(NSDate * _Nonnull)self.deviceCts] : @"";
    
}


@end
