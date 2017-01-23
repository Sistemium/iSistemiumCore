//
//  STMPersister.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSessionManagement.h"

#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMPersistingPromised.h"
#import "STMDocument.h"

#import "STMModelling.h"

@interface STMPersister : NSObject <STMPersistingSync, STMPersistingAsync, STMPersistingPromised, STMModelling>

@property (nonatomic, strong) STMDocument *document; // have to hide it from public (now it needs for session)

+ (instancetype)initWithSession:(id <STMSession>)session;


@end
