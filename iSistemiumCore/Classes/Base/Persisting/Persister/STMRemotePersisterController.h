//
//  STMRemotePersisterController.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 28/06/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

@interface STMRemotePersisterController : STMCoreController

+ (NSArray *)findAllRemote:(NSDictionary *)data;

@end
