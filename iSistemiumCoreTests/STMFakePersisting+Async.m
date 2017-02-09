///
///  STMFakePersisting+Async.m
///  iSisSales
///
///  Generated with Handlebars on Thu, 09 Feb 2017 16:15:31 GMT
///  Copyright © 2017 Sistemium UAB. All rights reserved.
///

#import "STMFakePersisting+Async.h"

#define STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


@implementation STMFakePersisting (Async)

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSDictionary * result = [self findSync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSArray * result = [self findAllSync:entityName predicate:predicate options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSDictionary * result = [self mergeSync:entityName attributes:attributes options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSArray * result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        [self destroySync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) completionHandler(!error, error);
        
    });
    
}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSUInteger result = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

- (void)updateAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_ASYNC_DISPATCH_QUEUE, 0), ^{
        
        NSError *error;
        NSDictionary * result = [self updateSync:entityName attributes:attributes options:options error:&error];
        if (completionHandler) completionHandler(!error, result, error);
        
    });
    
}

@end
