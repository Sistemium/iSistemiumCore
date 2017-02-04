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

#define STMFakePersistingPromisedWithSyncScalar(returnType,methodName,signatureAttributes) \
NSError *error; \
returnType result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
return [AnyPromise promiseWithValue: error ? error : @(result)];

#define STMFakePersistingPromisedWithSync(returnType,methodName,signatureAttributes) \
NSError *error; \
returnType *result = [self methodName##Sync:entityName signatureAttributes:signatureAttributes options:options error:&error]; \
return [AnyPromise promiseWithValue: error ? error : result];

#define STMFakePersistingEmptyResponse(returnValue) \
if (self.options[STMFakePersistingOptionEmptyDBKey]) { \
    return returnValue; \
} \
*error = STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR; \
return returnValue; \

#define STMFakePersistingIfInMemoryDB \
if (self.options[STMFakePersistingOptionInMemoryDBKey])

@interface STMFakePersisting ()

@property (nonatomic, strong) NSMutableDictionary <NSString*, NSMutableSet <NSDictionary*> *> *data;

@end


@implementation STMFakePersisting

- (void)setOptions:(NSDictionary *)options {
    if (options[STMFakePersistingOptionInMemoryDBKey]) {
        self.data = [NSMutableDictionary dictionary];
    }
    _options = options.copy;
}

+ (instancetype) fakePersistingWithOptions:(STMFakePersistingOptions)options {
    STMFakePersisting *result = [[self.class alloc] init];
    result.options = options;
    return result;
}


- (NSMutableSet <NSDictionary*> *)dataWithName:(NSString *)name {
    NSMutableSet *data = self.data[name];
    if (!data) {
        data = [NSMutableSet set];
        self.data[name] = data;
    }
    return data;
}

#pragma mark - PersistingSync implementation

- (NSDictionary *) findSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB {
        NSSet *found = [[self dataWithName:entityName] objectsPassingTest:^BOOL(NSDictionary *obj, BOOL * _Nonnull stop) {
            if (![identifier isEqualToString:obj[@"id"]]) return NO;
            *stop = @(YES);
            return YES;
        }];
        return found.allObjects.firstObject;
    }
    
    STMFakePersistingEmptyResponse(nil)

}

- (NSArray <NSDictionary*> *) findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB {
        return [[self dataWithName:entityName] filteredSetUsingPredicate:predicate].allObjects;
    }
    STMFakePersistingEmptyResponse(nil)

}

- (NSUInteger) countSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {

    return [self findAllSync:entityName predicate:predicate options:options error:error].count;

}

- (BOOL) destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB {
        NSDictionary *found = [self findSync:entityName identifier:identifier options:options error:error];
        [[self dataWithName:entityName] removeObject:found];
        return !!found;
    }
    
    STMFakePersistingEmptyResponse(NO)
    
}

- (NSDictionary *) mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    if (!attributes) {
        [STMFunctions error:error withMessage:@"Empty atributes in merge"];
        return nil;
    }
    
    STMFakePersistingIfInMemoryDB {
        [[self dataWithName:entityName] addObject:attributes];
        return attributes;
    }
    
    STMFakePersistingEmptyResponse(attributes)
    
}

- (NSUInteger) destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB {
        NSArray *found = [self findAllSync:entityName predicate:predicate options:options error:error];
        
        __block NSUInteger result = 0;
        
        [found enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
            result += [self destroySync:entityName identifier:obj[@"id"] options:options error:error];
        }];
        
        return result;
    }
    
    STMFakePersistingEmptyResponse(0)

}

- (NSArray *) mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB {
        [[self dataWithName:entityName] addObjectsFromArray:attributeArray];
        return attributeArray;
    }
    
    STMFakePersistingEmptyResponse(attributeArray)
    
}


#pragma mark - PersistingPromised implementation

- (AnyPromise *)find:(NSString *)entityName
          identifier:(NSString *)identifier
             options:(NSDictionary *)options {
    
    STMFakePersistingPromisedWithSync(NSDictionary,find,identifier)
    
}

- (AnyPromise *)findAll:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options {
    
    STMFakePersistingPromisedWithSync(NSArray,findAll,predicate)
    
}

- (AnyPromise *)merge:(NSString *)entityName
           attributes:(NSDictionary *)attributes
              options:(NSDictionary *)options {
    STMFakePersistingPromisedWithSync(NSDictionary,merge,attributes)
}

- (AnyPromise *)mergeMany:(NSString *)entityName
           attributeArray:(NSArray *)attributeArray
                  options:(NSDictionary *)options {
    
    STMFakePersistingPromisedWithSync(NSArray,mergeMany,attributeArray)
}

- (AnyPromise *)destroy:(NSString *)entityName
             identifier:(NSString *)identifier
                options:(NSDictionary *)options {
    
    STMFakePersistingPromisedWithSyncScalar(BOOL,destroy,identifier)
}

- (AnyPromise *)destroyAll:(NSString *)entityName
                 predicate:(NSPredicate *)predicate
                   options:(NSDictionary *)options {
    STMFakePersistingPromisedWithSyncScalar(NSUInteger,destroyAll,predicate)
}

@end
