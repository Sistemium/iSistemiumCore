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

#define STMPersisterAsyncWithSync(resultType,methodName,signatureAttributes) \
dispatch_async(dispatch_get_global_queue(STM_PERSISTER_ASYNC_DISPATCH_QUEUE, 0), ^{ \
NSError *error; \
resultType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
    if (completionHandler) completionHandler(!error,result,error); \
});


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

- (AnyPromise *)find:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self findAsync:entityName identifier:identifier options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)findAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self findAllAsync:entityName predicate:predicate options:options completionHandler:^(BOOL success, NSArray *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)merge:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self mergeAsync:entityName attributes:attributes options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)mergeMany:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self mergeManyAsync:entityName attributeArray:attributeArray options:options completionHandler:^(BOOL success, NSArray *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)destroy:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self destroyAsync:entityName identifier:identifier options:options completionHandler:^(BOOL success, NSError *error){
            if (success){
                resolve([NSNumber numberWithBool:success]);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)destroyAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options{
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self destroyAllAsync:entityName predicate:predicate options:options completionHandler:^(BOOL success, NSUInteger result, NSError *error){
            if (success){
                resolve(@(result));
            }else{
                resolve(error);
            }
        }];
    }];
    
}

- (AnyPromise *)update:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self updateAsync:entityName attributes:attributes options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

@end
