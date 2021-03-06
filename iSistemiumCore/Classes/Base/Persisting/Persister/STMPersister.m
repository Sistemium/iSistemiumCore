//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFunctions.h"

#import "STMPersister.h"
#import "STMPersister+Private.h"

#import "STMModeller+Interceptable.h"

@implementation STMPersister

+ (instancetype)persisterWithModelName:(NSString *)modelName completionHandler:(void (^)(BOOL success))completionHandler {

    STMPersister *persister = [[self alloc] initWithModelName:modelName];

    // TODO: call completionHandler after document is ready to rid off documentReady subscriptions
    if (completionHandler) completionHandler(YES);

    return persister;

}


- (instancetype)init {
    self = [super init];
    if (self) {
        self.dispatchQueue = dispatch_queue_create("com.sistemium.STMPersisterDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    return [super observeEntity:[STMFunctions addPrefixToEntityName:entityName]
                      predicate:predicate
                       callback:callback];
}

#pragma mark - STMPersistingSync


- (NSUInteger)countSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    __block NSUInteger result = 0;

    [self.runner readOnly:^NSArray *(id <STMPersistingTransaction> transaction) {
        result = [transaction count:entityName predicate:predicate options:options error:error];
        return nil;
    }];

    return result;

}

- (NSDictionary *)findSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error {

    NSPredicate *predicate = [self primaryKeyPredicateEntityName:entityName values:@[identifier]];

    NSArray *results = [self findAllSync:entityName predicate:predicate options:options error:error];

    return results.firstObject;

}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    // Allow pass nil in error
    __block NSError *innerError;

    NSArray *result = [self.runner readOnly:^NSArray *(id <STMPersistingTransaction> transaction) {
        return [transaction findAllSync:entityName predicate:predicate options:options error:&innerError];
    }];

    if (innerError && error) [STMFunctions error:error withMessage:innerError.localizedDescription];

    return result;

}


- (NSDictionary *)mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    attributes = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error];

    if (!attributes || *error) return nil;

    __block NSDictionary *result;

    [self.runner execute:^BOOL(id <STMPersistingTransaction> transaction) {

        result = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error inTransaction:transaction];

        // Exit if there's no result and no error from the interceptor, but don't rollback
        if (!result || *error) return !*error;

        result = [transaction mergeWithoutSave:entityName attributes:result options:options error:error];

        return !*error;

    }];

    if (*error) return nil;

    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                          ofUpdated:result ? result : nil
                            options:options];

    return result.copy;

}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    __block NSMutableArray *result = @[].mutableCopy;

    attributeArray = [self applyMergeInterceptors:entityName attributeArray:attributeArray options:options error:error];

    if (!attributeArray.count || *error) return attributeArray;

    [self.runner execute:^BOOL(id <STMPersistingTransaction> transaction) {

        for (NSDictionary *attributes in attributeArray) {

            NSDictionary *merged = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error inTransaction:transaction];

            if (*error) return NO;
            if (!merged) continue;

            merged = [transaction mergeWithoutSave:entityName attributes:merged options:options error:error];

            if (*error) return NO;
            if (merged) [result addObject:merged];

        }

        return YES;

    }];

    if (*error) return nil;

    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                     ofUpdatedArray:result.count ? result : attributeArray
                            options:options];

    return result.copy;

}

- (BOOL)destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error {

    NSUInteger deletedCount = [self destroyAllSync:entityName
                                         predicate:[self primaryKeyPredicateEntityName:entityName values:@[identifier]]
                                           options:options
                                             error:error];

    return deletedCount > 0;

}

- (NSUInteger)destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    __block NSUInteger count;

    [self.runner execute:^BOOL(id <STMPersistingTransaction> transaction) {

        count = [transaction destroyWithoutSave:entityName predicate:predicate options:options error:error];

        return !*error;

    }];

    return count;

}

- (NSDictionary *)updateSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    __block NSDictionary *result;

    [self.runner execute:^BOOL(id <STMPersistingTransaction> transaction) {

        result = [transaction updateWithoutSave:entityName attributes:attributes options:options error:error];

        return !*error;

    }];

    if (*error) return nil;

    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                          ofUpdated:result
                            options:options];

    return result;

}

@end
