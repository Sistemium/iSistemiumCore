//
//  STMFakePersistingSync.m
//  iSisSales
//
//  Created by Alexander Levin on 03/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting.h"
#import "STMFunctions.h"

#define STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR [NSError errorWithDomain:@"com.sistemium.iSistemiumCore" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Not implemented"}]

#define STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE [AnyPromise promiseWithValue:STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR]

#define STMFakePersistingEmptyResponsePromise(value) \
if (self.options[STMFakePersistingOptionEmptyDBKey]) { \
    return [AnyPromise promiseWithValue:value]; \
}

#define STMFakePersistingEmptyResponse(returnValue) \
if (self.options[STMFakePersistingOptionEmptyDBKey]) { \
    return returnValue; \
} \
*error = STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR; \
return returnValue; \

@interface STMFakePersisting ()

@end


@implementation STMFakePersisting

+ (instancetype) fakePersistingWithOptions:(STMFakePersistingOptions)options {
    STMFakePersisting *result = [[self.class alloc] init];
    result.options = options;
    return result;
}

#pragma mark - PersistingSync implementation

- (NSDictionary *) findSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingEmptyResponse(nil)

}

- (NSArray *) findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingEmptyResponse(nil)

}

- (NSUInteger) countSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingEmptyResponse(0)

}

- (BOOL) destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingEmptyResponse(NO)
    
}

- (NSDictionary *) mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingEmptyResponse(nil)
    
}

- (NSUInteger) destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingEmptyResponse(0)

}

- (NSArray *) mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingEmptyResponse(nil)
    
}


#pragma mark - PersistingPromised implementation

- (AnyPromise *)find:(NSString *)entityName
          identifier:(NSString *)identifier
             options:(NSDictionary *)options {
    
    STMFakePersistingEmptyResponsePromise(nil);
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

- (AnyPromise *)findAll:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options {
    STMFakePersistingEmptyResponsePromise(nil)
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

- (AnyPromise *)merge:(NSString *)entityName
           attributes:(NSDictionary *)attributes
              options:(NSDictionary *)options {
    if (!attributes) {
        return [AnyPromise promiseWithValue:[STMFunctions errorWithMessage:@"Empty atributes in merge"]];
    }
    STMFakePersistingEmptyResponsePromise(attributes)
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

- (AnyPromise *)mergeMany:(NSString *)entityName
           attributeArray:(NSArray *)attributeArray
                  options:(NSDictionary *)options {
    
    STMFakePersistingEmptyResponsePromise(attributeArray)
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

- (AnyPromise *)destroy:(NSString *)entityName
             identifier:(NSString *)identifier
                options:(NSDictionary *)options {
    
    STMFakePersistingEmptyResponsePromise(@NO)
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

- (AnyPromise *)destroyAll:(NSString *)entityName
                 predicate:(NSPredicate *)predicate
                   options:(NSDictionary *)options {
    
    STMFakePersistingEmptyResponsePromise(@(0))
    
    return STMFAKE_PERSISTING_NOT_IMPLEMENTED_PROMISE;
}

@end
