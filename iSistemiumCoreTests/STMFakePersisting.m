//
//  STMFakePersistingSync.m
//  iSisSales
//
//  Created by Alexander Levin on 03/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting.h"
#import "STMFunctions.h"
#import "STMIndexedArrayPersisting.h"


#define STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR \
[NSError errorWithDomain:@"com.sistemium.iSistemiumCore" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Not implemented"}]

#define STMFakePersistingEmptyResponse(returnValue) \
if (self.options[STMFakePersistingOptionEmptyDBKey]) { \
    return returnValue; \
} \
*error = STMFAKE_PERSISTING_NOT_IMPLEMENTED_ERROR; \
return returnValue; \

#define STMFakePersistingIfInMemoryDB(returnValue) \
if (options[STMPersistingOptionForceStorage] && ![options[STMPersistingOptionForceStorage] isEqual:@(STMStorageTypeInMemory)]) { \
    [STMFunctions error:error withMessage:@"OptionForceStorage is not available"]; \
    return returnValue; \
} \
if ([(NSNumber *)self.options[STMFakePersistingOptionCheckModelKey] boolValue]) { \
    if (![self isConcreteEntityName:entityName]) { \
        NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName]; \
        [STMFunctions error:error withMessage:message]; \
        return returnValue; \
    } \
} \
if (self.options[STMFakePersistingOptionInMemoryDBKey])


@interface STMFakePersisting ()

@property (nonatomic, strong) NSMutableDictionary <NSString*, STMIndexedArrayPersisting *> *data;

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

+ (instancetype)fakePersistingWithModelName:(NSString *)modelName options:(STMFakePersistingOptions)options {
    
    return [[STMFakePersisting fakePersistingWithOptions:options] initWithModel:[self modelWithName:modelName]];

}

- (void)setOption:(NSString *)option value:(NSString *)value {
    _options = [STMFunctions setValue:value forKey:option inDictionary:_options];
}


- (STMIndexedArrayPersisting *)dataWithName:(NSString *)name {
    STMIndexedArrayPersisting *data = self.data[name];
    if (!data) {
        data = [STMIndexedArrayPersisting array];
        self.data[name] = data;
    }
    return data;
}

#pragma mark - PersistingSync implementation

- (NSDictionary *) findSync:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB(nil) {
        
        STMIndexedArrayPersisting *data = [self dataWithName:entityName];
        return [data objectWithKey:identifier];
    }
    
    STMFakePersistingEmptyResponse(nil)

}

- (NSArray <NSDictionary*> *) findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB(nil) {
        
        NSMutableArray *predicates = @[].mutableCopy;
        
        if (options[STMPersistingOptionFantoms]) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom == 1"]];
        } else {
            [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom == 0 OR isFantom == nil"]];
        }
        
        if (predicate) [predicates addObject:predicate];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        
        NSArray <NSDictionary*> *result = [[self dataWithName:entityName] filteredArrayUsingPredicate:predicate];
        
        if (result && options[STMPersistingOptionOrder]) {
            result = [result sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* obj1, NSDictionary* obj2) {
                NSComparisonResult result = NSOrderedSame;
                NSArray *fields = [options[STMPersistingOptionOrder] componentsSeparatedByString:@","];
                for (NSString *field in fields) {
                    result = [(NSString *)obj1[field] compare:(NSString *)obj2[field] options:0];
                    if (result != NSOrderedSame) {
                        if (![options[STMPersistingOptionOrderDirection] isEqualToString:@"DESC"]) {
                            return result;
                        }
                        return result == NSOrderedAscending ? NSOrderedDescending : NSOrderedAscending;
                    }
                }
                return result;
            }];
        }
        
        return result;
    }
    
    STMFakePersistingEmptyResponse(nil)

}

- (NSUInteger) countSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {

    return [self findAllSync:entityName predicate:predicate options:options error:error].count;

}

- (BOOL) destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB(NO) {
        return [[self dataWithName:entityName] removeObjectWithKey:identifier];
    }
    
    STMFakePersistingEmptyResponse(NO)
    
}

- (NSDictionary *) mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {
    
    if (!attributes) {
        [STMFunctions error:error withMessage:@"Empty atributes in merge"];
        return nil;
    }
    
    STMFakePersistingIfInMemoryDB(nil) {
        attributes = [[self dataWithName:entityName] addObject:attributes options:options];
        [self notifyObservingEntityName:entityName ofUpdated:attributes];
        return attributes;
    }
    
    STMFakePersistingEmptyResponse(attributes)
    
}

- (NSUInteger) destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB(0) {
        
        NSArray *found = [self findAllSync:entityName predicate:predicate options:options error:error];
        
        __block NSUInteger result = 0;
        
        [found enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
            result += [self destroySync:entityName identifier:obj[STM_INDEXED_ARRAY_DEFAULT_PRIMARY_KEY] options:options error:error];
        }];
        
        return result;
    }
    
    STMFakePersistingEmptyResponse(0)

}

- (NSArray *) mergeManySync:(NSString *)entityName attributeArray:(NSArray <NSDictionary*> *)attributeArray options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB(nil) {
        attributeArray = [[self dataWithName:entityName] addObjectsFromArray:attributeArray options:options];
        [self notifyObservingEntityName:entityName ofUpdatedArray:attributeArray];
        return attributeArray;
    }
    
    STMFakePersistingEmptyResponse(attributeArray)
    
}

- (NSDictionary *) updateSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    STMFakePersistingIfInMemoryDB(nil) {
        
        NSString *identifier = attributes[STM_INDEXED_ARRAY_DEFAULT_PRIMARY_KEY];
        
        if (!identifier) {
            [STMFunctions error:error withMessage:@"No primary key in attributes"];
            return nil;
        }
        
        NSDictionary *found = [self findSync:entityName identifier:identifier options:options error:error];
        
        // TODO: maybe need an option to control if not found updates return errors
        if (!found) return nil;
        
        NSArray *fieldsToUpdate = options[STMPersistingOptionFieldstoUpdate];
        
        if (fieldsToUpdate) {
            attributes = [attributes dictionaryWithValuesForKeys:fieldsToUpdate];
        }
        
        NSMutableDictionary *merged = found.mutableCopy;
        [merged addEntriesFromDictionary:attributes];
        
        return [self mergeSync:entityName attributes:merged options:options error:error];
        
    }
    
    STMFakePersistingEmptyResponse(nil)
    
}

@end
