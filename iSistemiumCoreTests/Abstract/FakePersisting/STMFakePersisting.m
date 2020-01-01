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
#import "STMLazyDictionary.h"

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
if (!entityName) { \
    [STMFunctions error:error withMessage:@"Entity name can not be null"]; \
    return returnValue; \
} \
entityName = [STMFunctions addPrefixToEntityName:entityName]; \
if ([(NSNumber *)self.options[STMFakePersistingOptionCheckModelKey] boolValue]) { \
    if (![self isConcreteEntityName:entityName]) { \
        NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName]; \
        [STMFunctions error:error withMessage:message]; \
        return returnValue; \
    } \
} \
if (self.options[STMFakePersistingOptionInMemoryDBKey])

@interface STMFakePersisting ()

@property (nonatomic, strong) STMLazyDictionary <NSString *, STMIndexedArrayPersisting *> *data;

@end


@implementation STMFakePersisting

+ (instancetype) fakePersistingWithOptions:(STMFakePersistingOptions)options {
    return [[self alloc] initWithPersistingOptions:options];
}

+ (instancetype)fakePersistingWithModelName:(NSString *)modelName options:(STMFakePersistingOptions)options {
    return [[self fakePersistingWithOptions:options] initWithModel:[self modelWithName:modelName] modelName:modelName];
}

- (instancetype)initWithPersistingOptions:(STMFakePersistingOptions)options {
    [self init].options = options.copy;
    return self;
}

- (void)setOptions:(NSDictionary *)options {
    if (options[STMFakePersistingOptionInMemoryDBKey] && !_options[STMFakePersistingOptionInMemoryDBKey]) {
        self.data = [STMLazyDictionary lazyDictionaryWithItemsClass:STMIndexedArrayPersisting.class];
    } else if (!options[STMFakePersistingOptionInMemoryDBKey]) {
        self.data = nil;
    }
    _options = options.copy;
}

- (void)setOption:(NSString *)option value:(NSString *)value {
    self.options = [STMFunctions setValue:value forKey:option inDictionary:self.options];
}

#pragma mark - PersistingObserving override

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    return [super observeEntity:[STMFunctions addPrefixToEntityName:entityName]
                      predicate:predicate
                       callback:callback];
}

#pragma mark - PersistingSync implementation

- (NSDictionary *) findSync:(NSString *)entityName identifier:(NSString *)identifier options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB(nil) {
        return [self.data[entityName] objectWithKey:identifier];
    }
    
    STMFakePersistingEmptyResponse(nil)

}

- (NSArray <NSDictionary*> *) findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {

    STMFakePersistingIfInMemoryDB(nil) {
        
        NSMutableArray *predicates = @[].mutableCopy;
        
        if (options[STMPersistingOptionPhantoms]) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom == 1"]];
        } else {
            [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom == 0 OR isFantom == nil"]];
        }
        
        if (predicate) [predicates addObject:predicate];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        
        NSArray <NSDictionary*> *result = [self.data[entityName] filteredArrayUsingPredicate:predicate];
        
        NSArray *groupBy = options[STMPersistingOptionGroupBy];
        
        NSMutableDictionary<NSString *,NSMutableDictionary *> *grouped = @{}.mutableCopy;
        
        if (groupBy !=nil && groupBy.count > 0){
            for (NSDictionary *data in result){
                NSString *groupKey = @"";
                for (NSString *groupName in groupBy){
                    groupKey = [groupKey stringByAppendingString:[data[groupName] description]];
                }
                if ([grouped.allKeys containsObject:groupKey]){
                    NSMutableDictionary *mutable = grouped[groupKey];
                    mutable[@"count()"] = [NSNumber numberWithInteger:[mutable[@"count()"] integerValue] + 1];
                    grouped[groupKey] = mutable;
                }else{
                    grouped[groupKey] = @{@"count()":[NSNumber numberWithInteger:1]}.mutableCopy;
                    
                    for (NSString *groupName in groupBy){
                        
                        grouped[groupKey][groupName] = data[groupName];
                        
                    }
                }
            }
            
            NSMutableArray *mutResult = @[].mutableCopy;
            
            for (NSMutableDictionary *mutable in grouped.allValues){
                [mutResult addObject:mutable.copy];
            }
            
            result = mutResult.copy;
        }
        
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
        return [self.data[entityName] removeObjectWithKey:identifier];
    }
    
    STMFakePersistingEmptyResponse(NO)
    
}

- (NSDictionary *) mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(STMPersistingOptions)options error:(NSError *__autoreleasing *)error {
    
    if (!attributes) {
        [STMFunctions error:error withMessage:@"Empty atributes in merge"];
        return nil;
    }
    
    STMFakePersistingIfInMemoryDB(nil) {
        
        attributes = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error];
        
        if (*error) return nil;
        
        if (!attributes) {
            [STMFunctions error:error withMessage:@"Emtpy response from the interceptor"];
            return nil;
        }
        
        attributes = [self.data[entityName] addObject:attributes options:options];
        [self notifyObservingEntityName:entityName ofUpdated:attributes options:options];
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
        attributeArray = [self applyMergeInterceptors:entityName attributeArray:attributeArray options:options error:error];
        
        if (*error) return nil;
        
        if (!attributeArray) {
            [STMFunctions error:error withMessage:@"Emtpy response from the interceptor"];
            return nil;
        }
        
        attributeArray = [self.data[entityName] addObjectsFromArray:attributeArray options:options];
        [self notifyObservingEntityName:entityName ofUpdatedArray:attributeArray options:options];
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
        
        NSArray *fieldsToUpdate = options[STMPersistingOptionFieldsToUpdate];
        
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
