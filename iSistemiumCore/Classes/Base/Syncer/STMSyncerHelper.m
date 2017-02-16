//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Private.h"


@implementation STMSyncerHelper

- (instancetype)initWithPersistenceDelegate:(id)persistenceDelegate {
    
    self = [super init];
    if (self) {
        self.persistenceDelegate = persistenceDelegate;
    }
    return self;
    
}

#pragma mark - Private Properties

@synthesize dataDownloadingOwner = _dataDownloadingOwner;

@end
