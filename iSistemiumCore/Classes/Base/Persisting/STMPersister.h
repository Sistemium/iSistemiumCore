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

#import "STMModeller.h"
#import "STMFmdb.h"

@interface STMPersister : STMModeller <STMPersistingSync>

@property (nonatomic, strong) STMFmdb *fmdb;
@property (nonatomic, strong) STMDocument *document;

+ (instancetype)initWithSession:(id <STMSession>)session;

@end
