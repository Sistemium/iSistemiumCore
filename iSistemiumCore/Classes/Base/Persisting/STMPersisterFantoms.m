//
//  STMPersisterFantoms.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterFantoms.h"

@implementation STMPersisterFantoms

- (NSArray *)findAllFantomsIdsSync:(NSString *)entityName excludingIds:(NSArray *)excludingIds {
    
    NSError *error = nil;
    
    NSArray *result = [self.persistenceDelegate findAllSync:entityName
                                                  predicate:nil
                                                    options:@{STMPersistingOptionFantoms : @YES}
                                                      error:&error];
    
    result = [result valueForKeyPath:@"id"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", excludingIds];
    
    return [result filteredArrayUsingPredicate:predicate];
    
}

- (BOOL)destroyFantomSync:(NSString *)entityName identifier:(NSString *)identifier {
    
    NSError *error = nil;
    
    return [self.persistenceDelegate destroySync:entityName
                                      identifier:identifier
                                         options:@{STMPersistingOptionRecordstatuses: @NO}
                                           error:&error];
    
}

- (NSDictionary *)mergeFantomSync:(NSString *)entityName attributes:(NSDictionary *)attributes error:(NSError *__autoreleasing *)error {
    
    return [self.persistenceDelegate mergeSync:entityName
                                    attributes:attributes
                                       options:@{STMPersistingOptionLtsNow}
                                         error:error];

}

- (void)mergeFantomAsync:(NSString *)entityName
                        attributes:(NSDictionary *)attributes
                          callback:(STMPersistingAsyncDictionaryResultCallback)callback {
    
    return [self.persistenceDelegate mergeAsync:entityName
                                     attributes:attributes
                                        options:@{STMPersistingOptionLtsNow}
                              completionHandler:callback];
}


@end
