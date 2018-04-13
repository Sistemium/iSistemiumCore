//
//  STMPersistingInterceptorUniqueProperty.m
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingInterceptorUniqueProperty.h"

@implementation STMPersistingInterceptorUniqueProperty

- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inTransaction:(id <STMPersistingTransaction>)transaction {

    id value = attributes[self.propertyName];

    if (!value || [value isEqual:[NSNull null]]) {
        [STMFunctions error:error withMessage:[self.propertyName stringByAppendingString:@" can not be null in STMPersisterInterceptorUniqueProperty"]];
        return nil;
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:[self.propertyName stringByAppendingString:@" == %@"], value];

    NSDictionary *findOptions = @{STMPersistingOptionPageSize: @(1)};

    NSDictionary *existing = [transaction findAllSync:self.entityName predicate:predicate options:findOptions error:error].firstObject;

    if (!existing) return attributes;

    return [STMFunctions setValue:existing[STMPersistingKeyPrimary] forKey:STMPersistingKeyPrimary inDictionary:attributes];

}

@end
