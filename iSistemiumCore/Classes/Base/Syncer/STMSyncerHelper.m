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

@synthesize downloadingState = _downloadingState;
@synthesize dataDownloadingOwner = _dataDownloadingOwner;


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

- (NSMutableDictionary *)stcEntities {
    
    if (!_stcEntities) {
        _stcEntities = [STMEntityController stcEntities].mutableCopy;
    }
    return _stcEntities;
    
}

- (id <STMSession>)session {
    return [[STMSessionManager sharedManager] currentSession];
}

- (STMDocument *)document {
    return self.session.document;
}


@end
