//
//  STMPersister+Async.m
//  iSisSales
//
//  Created by Alexander Levin on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Async.h"
#import "STMFmdb.h"


#define STM_PERSISTER_ASYNC_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT
#define STM_PERSISTER_PROMISED_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


#define STMPersisterAsyncWithSync(resultType,methodName,signatureAttributes) \
dispatch_async(dispatch_get_global_queue(STM_PERSISTER_ASYNC_DISPATCH_QUEUE, 0), ^{ \
    NSError *error; \
    resultType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
        if (completionHandler) completionHandler(!error,result,error); \
    });

#define STMPersisterPromisedWithSyncScalar(returnType,methodName,signatureAttributes) \
return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){ \
    dispatch_async(dispatch_get_global_queue(STM_PERSISTER_PROMISED_DISPATCH_QUEUE, 0), ^{ \
        NSError *error; \
        returnType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
        if (error) resolve(error); else resolve(@(result)); \
    }); \
}];

#define STMPersisterPromisedWithSync(returnType,methodName,signatureAttributes) \
return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){ \
    dispatch_async(dispatch_get_global_queue(STM_PERSISTER_PROMISED_DISPATCH_QUEUE, 0), ^{ \
        NSError *error; \
        returnType *result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
        if (error) resolve(error); else resolve(result); \
    }); \
}];


@implementation STMPersister (Async)

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    STMPersisterAsyncWithSync(NSDictionary *,find,identifier)
    
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    STMPersisterAsyncWithSync(NSArray *,findAll,predicate)
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    STMPersisterAsyncWithSync(NSDictionary *,merge,attributes)
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    STMPersisterAsyncWithSync(NSArray *,mergeMany,attributeArray)
}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler {
    dispatch_async(dispatch_get_global_queue(STM_PERSISTER_ASYNC_DISPATCH_QUEUE, 0), ^{
        NSError *error;
        BOOL result = [self destroySync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) completionHandler(result,error);
    });
    
}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler {
    STMPersisterAsyncWithSync(NSUInteger,destroyAll,predicate)
}

- (void)updateAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    STMPersisterAsyncWithSync(NSDictionary *,update,attributes)
}


#pragma mark - STMPersistingPromised


- (AnyPromise *)find:(NSString *)entityName
          identifier:(NSString *)identifier
             options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSync(NSDictionary,find,identifier)
}

- (AnyPromise *)findAll:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSync(NSArray,findAll,predicate)
}

- (AnyPromise *)merge:(NSString *)entityName
           attributes:(NSDictionary *)attributes
              options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSync(NSDictionary,merge,attributes)
}

- (AnyPromise *)mergeMany:(NSString *)entityName
           attributeArray:(NSArray *)attributeArray
                  options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSync(NSArray,mergeMany,attributeArray)
}

- (AnyPromise *)destroy:(NSString *)entityName
             identifier:(NSString *)identifier
                options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSyncScalar(BOOL,destroy,identifier)
}

- (AnyPromise *)destroyAll:(NSString *)entityName
                 predicate:(NSPredicate *)predicate
                   options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSyncScalar(NSUInteger,destroyAll,predicate)
}

- (AnyPromise *)update:(NSString *)entityName
                 attributes:(NSDictionary *)attributes
                   options:(STMPersistingOptions)options {
    STMPersisterPromisedWithSync(NSDictionary,update,attributes)
}

@end
