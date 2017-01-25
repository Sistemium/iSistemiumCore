//
//  STMPersister.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSessionManagement.h"

#import "STMPersistingSync.h"
#import "STMDocument.h"

#import "STMModelling.h"
#import "STMFmdb.h"

@interface STMPersister : NSObject <STMPersistingSync, STMModelling>

@property (nonatomic, strong) STMFmdb *fmdb;

@property (nonatomic, strong) STMDocument *document; // have to hide it from public (now it needs for session)

+ (instancetype)initWithSession:(id <STMSession>)session;


@end
