//
//  STMCoreSession+Persistable.h
//  iSisSales
//
//  Created by Alexander Levin on 29/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession.h"

@interface STMCoreSession (Persistable)

- (instancetype)initPersistable;
- (void)removePersistable:(void (^)(BOOL success))completionHandler;

@end
