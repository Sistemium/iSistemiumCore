//
//  STMPersister+Async.m
//  iSisSales
//
//  Created by Alexander Levin on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Async.h"
#import "STMFmdb.h"

@implementation STMPersister (Async)

#pragma mark - STMPersistingAsync

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findSync:entityName identifier:identifier options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self findSync:entityName identifier:identifier options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findAllSync:entityName predicate:predicate options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self findAllSync:entityName predicate:predicate options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeSync:entityName attributes:attributes options:options error:&error];
            if(error){
                success = NO;
            }
            if (completionHandler) completionHandler(success,result,error);
        });
    } else {
        result = [self mergeSync:entityName attributes:attributes options:options error:&error];
        if(error){
            success = NO;
        }
        if (completionHandler) completionHandler(success,result,error);
    }
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSError *error))completionHandler{
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            success = [self destroySync:entityName identifier:identifier options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,error);
        });
    }else{
        success = [self destroySync:entityName identifier:identifier options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,error);
    }
}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options
      completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler{
    
    __block BOOL success = YES;
    __block NSError* error = nil;
    __block NSUInteger result = 0;
    
    if ([self.fmdb hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
    
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

@end
