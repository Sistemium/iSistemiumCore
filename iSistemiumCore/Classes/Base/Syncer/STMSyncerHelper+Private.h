//
//  STMSyncerHelper+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 15/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

@interface STMDataDownloadingState : STMCoreObject <STMDataSyncingState>

@end


@interface STMSyncerHelper ()

@property (nonatomic,strong) STMDataDownloadingState *downloadingState;

@end
