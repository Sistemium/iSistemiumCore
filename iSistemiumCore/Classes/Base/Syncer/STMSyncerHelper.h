//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMCoreController.h"


@interface STMSyncerHelper : STMCoreController

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@end


#import "STMSyncerHelper+Downloading.h"

