//
//  STMPersister+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"
#import "STMPersistingRunning.h"

@interface STMPersister()

@property (nonatomic,strong) NSString *fmdbFileName;
@property (nonatomic,strong) id<STMPersistingRunning> persistingRunning;

@end
