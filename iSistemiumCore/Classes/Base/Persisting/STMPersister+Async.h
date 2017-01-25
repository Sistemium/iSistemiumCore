//
//  STMPersister+Async.h
//  iSisSales
//
//  Created by Alexander Levin on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"
#import "STMPersistingAsync.h"
#import "STMPersistingPromised.h"

@interface STMPersister (Async) <STMPersistingAsync, STMPersistingPromised>


@end
