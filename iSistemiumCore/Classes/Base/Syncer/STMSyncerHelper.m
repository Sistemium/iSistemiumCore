//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Private.h"


@implementation STMSyncerHelper

@synthesize dataDownloadingOwner = _dataDownloadingOwner;
@synthesize defantomizingOwner = _defantomizingOwner;
@synthesize persistenceFantomsDelegate = _persistenceFantomsDelegate;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.dispatchQueue = dispatch_queue_create("STMSyncerHelperDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

@end
