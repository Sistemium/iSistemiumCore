//
//  STMFakePersisting+Promised.m
//  iSisSales
//
//  Generated with HandlebarsGenerator on Thu, 09 Feb 2017 19:04:13 GMT
//  Don't edit this file directly!
//
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting+Promised.h"

#define STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE DISPATCH_QUEUE_PRIORITY_DEFAULT


@implementation STMFakePersisting (Promised)

- (AnyPromise *)find:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

            NSError *error;
            NSDictionary * result = [self findSync:entityName identifier:identifier options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)findAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

            NSError *error;
            NSArray * result = [self findAllSync:entityName predicate:predicate options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)merge:(NSString *)entityName attributes:(NSDictionary *)attributes options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

            NSError *error;
            NSDictionary * result = [self mergeSync:entityName attributes:attributes options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)mergeMany:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

            NSError *error;
            NSArray * result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

- (AnyPromise *)destroy:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options {

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

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

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

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

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(STM_FAKE_PERSISTING_PROMISED_DISPATCH_QUEUE, 0), ^{

            NSError *error;
            NSDictionary * result = [self updateSync:entityName attributes:attributes options:options error:&error];

            if (error) {
                resolve(error);
            } else {
                resolve(result);
            }

        });
    }];

}

@end