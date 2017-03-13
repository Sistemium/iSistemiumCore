//
//  STMPersister+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"

@interface STMPersister()

@property (nonatomic,strong) NSString *fmdbFileName;

- (void)wrongEntityName:(NSString *)entityName error:(NSError **)error;

@end
