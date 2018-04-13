//
//  STMPersister+Async.m
//  iSisSales
//
//  Generated with HandlebarsGenerator
//  Don't edit this file directly!
//
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Async.h"


@implementation STMPersister (Async)

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSDictionary *result = [self findSync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSArray *result = [self findAllSync:entityName predicate:predicate options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSDictionary *result = [self mergeSync:entityName attributes:attributes options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSArray *result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}

- (void)destroyAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        [self destroySync:entityName identifier:identifier options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, error);
            });
        }

    });

}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSUInteger result = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}

- (void)updateAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {

    dispatch_async(self.dispatchQueue, ^{

        NSError *error;
        NSDictionary *result = [self updateSync:entityName attributes:attributes options:options error:&error];
        if (completionHandler) {
            dispatch_async(self.dispatchQueue, ^{
                completionHandler(!error, result, error);
            });
        }

    });

}


#pragma mark - STMPersistingPromised


- (AnyPromise *)find:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSDictionary *result = [self findSync:entityName identifier:identifier options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)findAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSArray *result = [self findAllSync:entityName predicate:predicate options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)merge:(NSString *)entityName attributes:(NSDictionary *)attributes options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSDictionary *result = [self mergeSync:entityName attributes:attributes options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)mergeMany:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSArray *result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)destroy:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            BOOL result = [self destroySync:entityName identifier:identifier options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(@(result));
            }

        });
    }];

}

- (AnyPromise *)destroyAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSUInteger result = [self destroyAllSync:entityName predicate:predicate options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(@(result));
            }

        });
    }];

}

- (AnyPromise *)update:(NSString *)entityName attributes:(NSDictionary *)attributes options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        dispatch_async(self.dispatchQueue, ^{

            NSError *error;
            NSDictionary *result = [self updateSync:entityName attributes:attributes options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

@end