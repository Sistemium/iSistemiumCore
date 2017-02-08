//
//  STMFakePersisting+Async.m
//  iSisSales
//
//  Created by Alexander Levin on 06/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting+Async.h"

#define STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT

#define STMFakePersistingAsyncWithSync(resultType,methodName,signatureAttributes) \
dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{ \
    NSError *error; \
    resultType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
    if (completionHandler) completionHandler(!error,result,error); \
});


@implementation STMFakePersisting (Async)

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {

    STMFakePersistingAsyncWithSync(NSDictionary *,find,identifier)
    
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    STMFakePersistingAsyncWithSync(NSArray *,findAll,predicate)
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    STMFakePersistingAsyncWithSync(NSDictionary *,merge,attributes)
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    STMFakePersistingAsyncWithSync(NSArray *,mergeMany,attributeArray)
}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler {
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        NSError *error;
        BOOL result = [self destroySync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) completionHandler(result,error);
    });

}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler {
    STMFakePersistingAsyncWithSync(NSUInteger,destroyAll,predicate)
}


- (void)updateAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    STMFakePersistingAsyncWithSync(NSDictionary *,update,attributes)
}

@end
