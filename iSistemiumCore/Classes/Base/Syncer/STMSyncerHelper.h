//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncing.h"


@interface STMSyncerHelper : NSObject <STMDataSyncing>

@property (nonatomic, strong, readonly) NSMutableArray *failToResolveFantomsArray;


@end
