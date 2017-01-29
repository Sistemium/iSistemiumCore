//
//  STMPersister+Observable.h
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"
#import "STMPersistingObserving.h"

@interface STMPersister (Observable) <STMPersistingObserving>

- (void)notifyObservingEntityName:(NSString *)entityName
                        ofUpdated:(NSDictionary *)attributes;

@end
