//
//  STMPersistingObservable.h
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingObserving.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMPersistingObservable : NSObject <STMPersistingObserving>

- (void)notifyObservingEntityName:(NSString *)entityName
                        ofUpdated:(NSDictionary *)item;

- (void)notifyObservingEntityName:(NSString *)entityName
                   ofUpdatedArray:(NSArray *)items;

@end

NS_ASSUME_NONNULL_END
