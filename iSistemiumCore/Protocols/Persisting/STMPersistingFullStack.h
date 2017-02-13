//
//  STMPersistingFullStack.h
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#ifndef STMPersistingFullStack_h
#define STMPersistingFullStack_h

#import "STMPersistingPromised.h"
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMPersistingObserving.h"
#import "STMModelling.h"

#define STMPersistingFullStack STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMPersistingObserving, STMModelling

#endif /* STMPersistingFullStack_h */
