//
//  STMFakePersisting+Promised.m
//  iSisSales
//
//  Created by Alexander Levin on 06/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting+Promised.h"


#define STMFakePersistingPromisedWithSyncScalar(returnType,methodName,signatureAttributes) \
NSError *error; \
returnType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
return [AnyPromise promiseWithValue: error ? error : @(result)];

#define STMFakePersistingPromisedWithSync(returnType,methodName,signatureAttributes) \
NSError *error; \
returnType *result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
return [AnyPromise promiseWithValue: error ? error : result];


@implementation STMFakePersisting (Promised)

#pragma mark - PersistingPromised implementation

- (AnyPromise *)find:(NSString *)entityName
          identifier:(NSString *)identifier
             options:(STMPersistingOptions)options {
    
    STMFakePersistingPromisedWithSync(NSDictionary,find,identifier)
    
}

- (AnyPromise *)findAll:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(STMPersistingOptions)options {
    
    STMFakePersistingPromisedWithSync(NSArray,findAll,predicate)
    
}

- (AnyPromise *)merge:(NSString *)entityName
           attributes:(NSDictionary *)attributes
              options:(STMPersistingOptions)options {
    STMFakePersistingPromisedWithSync(NSDictionary,merge,attributes)
}

- (AnyPromise *)mergeMany:(NSString *)entityName
           attributeArray:(NSArray *)attributeArray
                  options:(STMPersistingOptions)options {
    
    STMFakePersistingPromisedWithSync(NSArray,mergeMany,attributeArray)
}

- (AnyPromise *)destroy:(NSString *)entityName
             identifier:(NSString *)identifier
                options:(STMPersistingOptions)options {
    
    STMFakePersistingPromisedWithSyncScalar(BOOL,destroy,identifier)
}

- (AnyPromise *)destroyAll:(NSString *)entityName
                 predicate:(NSPredicate *)predicate
                   options:(STMPersistingOptions)options {
    STMFakePersistingPromisedWithSyncScalar(NSUInteger,destroyAll,predicate)
}

@end

