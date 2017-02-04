//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

#import "STMConstants.h"
#import "STMEntityController.h"

@interface STMSyncerHelper()

@end


@implementation STMSyncerHelper

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {
    _failToResolveFantomsArray = @[].mutableCopy;
}


@end
