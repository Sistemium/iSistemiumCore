//
//  STMFakePersisting+Promised.m
//  iSisSales
//
//  Created by Alexander Levin on 06/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting+Promised.h"

#define STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


#define STMFakePersistingPromisedWithSyncScalar(returnType,methodName,signatureAttributes) \
return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){ \
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{ \
        NSError *error; \
        returnType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
        if (error) resolve(error); else resolve(@(result)); \
    }); \
}];

#define STMFakePersistingPromisedWithSync(returnType,methodName,signatureAttributes) \
return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){ \
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{ \
        NSError *error; \
        returnType *result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
        if (error) resolve(error); else resolve(result); \
    }); \
}];

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

