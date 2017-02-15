//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Private.h"


@implementation STMSyncerHelper

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {

}

- (id <STMSession>)session {
    return [[STMSessionManager sharedManager] currentSession];
}


#pragma mark - Private Properties

@synthesize dataDownloadingOwner = _dataDownloadingOwner;

@end
