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

@interface STMPersister : NSObject <STMPersistingSync, STMPersistingAsync, STMPersistingPromised>

+ (instancetype)initWithDocument:(STMDocument *)stmdocument
                      forSession:(id <STMSession>)session;


@end
