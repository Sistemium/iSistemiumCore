//
//  STMSyncerHelper+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 15/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"
#import "STMSyncerHelper+Defantomizing.h"

@interface STMDataDownloadingState : STMCoreObject <STMDataSyncingState>

@end

@interface STMSyncerHelperDefantomizing : NSObject

@end

@interface STMSyncerHelper ()

@property (nonatomic,strong) STMDataDownloadingState *downloadingState;
@property (nonatomic,weak) id <STMDefantomizingOwner> defantomizingOwner;

@property (nonatomic, strong) STMSyncerHelperDefantomizing *defantomizing;

@end
