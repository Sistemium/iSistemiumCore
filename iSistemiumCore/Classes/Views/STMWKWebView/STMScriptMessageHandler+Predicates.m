//
//  STMScriptMessagesController.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 29/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMFunctions.h"
#import "STMScriptMessageHandler+Predicates.h"

typedef NSArray <STMScriptMessagingFilterDictionary *> STMScriptMessagingFiltersArray;
typedef NSMutableArray <STMScriptMessagingFilterDictionary *> STMScriptMessagingFiltersMutableArray;

@implementation STMScriptMessageHandler (Predicates)

- (NSPredicate *)predicateForScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error {
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [self error:error withMessage:@"message body is not a Dictionary"];
        return nil;
        
    }
    
    NSDictionary *body = scriptMessage.body;
    
    if (![body[@"entity"] isKindOfClass:[NSString class]]) {
        
        [self error:error withMessage:@"message body have no entity name"];
        return nil;
        
    }
    
    NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:(NSString *)body[@"entity"]];
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND]) {
        
        if (![body[@"id"] isKindOfClass:[NSString class]]) {
            
            [self error:error withMessage:[NSString stringWithFormat:@"where is no xid in %@ script message", scriptMessage.name]];
            return nil;
            
        }
        
        NSData *xid = [STMFunctions xidDataFromXidString:body[@"id"]];
        
        return [self predicateForEntityName:entityName
                                     filter:@{@"xid": xid}
                                whereFilter:nil
                                      error:error];
        
    } else if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND_ALL]) {
        
        NSDictionary *filter = ([body[@"filter"] isKindOfClass:[self filterClass]]) ? body[@"filter"] : nil;
        //        if (!filter) NSLog(@"filter section malformed");
        
        NSDictionary *whereFilter = ([body[@"where"] isKindOfClass:[self whereFilterClass]]) ? body[@"where"] : nil;
        //        if (!whereFilter) NSLog(@"whereFilter section malformed");
        
        return [self predicateForEntityName:entityName
                                     filter:filter
                                whereFilter:whereFilter
                                      error:error];
        
    } else {
        
        [self error:error withMessage:[NSString stringWithFormat:@"unknown script message with name %@", scriptMessage.name]];
        return nil;
        
    }
    
}


#pragma mark - Private helpers

- (Class)filterClass {
    return [NSDictionary <NSString *, __kindof NSObject *> class];
}

- (Class)whereFilterClass {
    return [NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> class];
}

- (NSArray <NSString *> *)comparisonOperators {
    return @[@"==", @"!=", @">=", @"<=", @">", @"<", @"like", @"likei"];
}


- (NSPredicate *)predicateForEntityName:(NSString *)entityName
                                 filter:(STMScriptMessagingFilterDictionary *)filter
                            whereFilter:(STMScriptMessagingWhereFilterDictionary *)whereFilter
                                  error:(NSError **)error {
    
    NSMutableDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *filterDictionary = whereFilter ? whereFilter.mutableCopy : @{}.mutableCopy;
    
    for (NSString *key in filter.allKeys) {
        filterDictionary[key] = @{@"==" : filter[key]};
    }
    
    if (filterDictionary.count == 0) return nil;
    
    NSMutableArray <NSPredicate *> *subpredicates = @[].mutableCopy;
    
    STMScriptMessagingFiltersArray *subpredicatesDics = [self subpredicatesDicsForEntityName:entityName
                                                                            filterDictionary:filterDictionary];
    
    for (NSDictionary <NSString *, __kindof NSObject *> *subpredicateDic in subpredicatesDics) {
        
        NSString *format = subpredicateDic.allKeys.firstObject;
        __kindof NSObject *argument = subpredicateDic.allValues.firstObject;
        
        argument = ([argument isKindOfClass:[NSNull class]]) ? nil : @[argument];
        
        NSPredicate *subpredicate = [NSPredicate predicateWithFormat:format
                                                       argumentArray:argument];
        
        [subpredicates addObject:subpredicate];
        
    }
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
}

- (STMScriptMessagingFiltersArray *)subpredicatesDicsForEntityName:(NSString *)entityName
                                                  filterDictionary:(STMScriptMessagingWhereFilterDictionary *)filterDictionary {
    
    
    NSEntityDescription *entityDescription = self.modellingDelegate.entitiesByName[entityName];
    
    NSDictionary <NSString *, __kindof NSPropertyDescription *> *properties = entityDescription.propertiesByName;
    NSDictionary <NSString *, NSAttributeDescription *> *attributes = entityDescription.attributesByName;
    NSDictionary <NSString *, NSRelationshipDescription *> *relationships = entityDescription.relationshipsByName;
    
    STMScriptMessagingFiltersMutableArray *subpredicatesDics = @[].mutableCopy;
    
    for (NSString *key in filterDictionary.allKeys) {
        
        STMScriptMessagingWhereFilterDictionary *filterArguments = filterDictionary[key];
        
        STMScriptMessagingFiltersArray *result = @[];
        
        if ([key hasPrefix:@"ANY"]) {
            
            result = [self anyConditionForKey:key
                              filterArguments:filterArguments
                                relationships:relationships
                                   entityName:entityName];
            
        } else {
            
            result = [self subpredicatesDicsForFilterKey:key
                                         filterArguments:filterArguments
                                           relationships:relationships
                                              attributes:attributes
                                              properties:properties
                                              entityName:entityName];
            
        }

        [subpredicatesDics addObjectsFromArray:result];
        
    }
    
    return subpredicatesDics.copy;
    
}

- (STMScriptMessagingFiltersArray *)subpredicatesDicsForFilterKey:(NSString *)key
                                                  filterArguments:(STMScriptMessagingWhereFilterDictionary *)filterArguments
                                                    relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships
                                                       attributes:(NSDictionary <NSString *, NSAttributeDescription *> *)attributes
                                                       properties:(NSDictionary <NSString *, __kindof NSPropertyDescription *> *)properties
                                                       entityName:(NSString *)entityName {
    
    NSMutableArray *keyComponents = [key componentsSeparatedByString:@"."].mutableCopy;
    
    if (keyComponents.count > 1) {
        
//        NSLog(@"have complex key");
        NSString *keyHead = keyComponents.firstObject;
        NSRelationshipDescription *relationship = relationships[keyHead];
        
        if (!relationship) {
            
            NSLog(@"have no relationship %@", keyHead);
            return nil;
            
        }
        
        [keyComponents removeObject:keyHead];
        NSString *filterKey = [keyComponents componentsJoinedByString:@"."];
        
        STMScriptMessagingFiltersArray *result = [self subpredicatesDicsForEntityName:relationship.destinationEntity.name
                                                                     filterDictionary:@{filterKey: filterArguments}];
        
        STMScriptMessagingFiltersMutableArray *returnResult = @[].mutableCopy;
        
        [result enumerateObjectsUsingBlock:^(STMScriptMessagingFilterDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
           
            STMScriptMessagingFilterMutableDictionary *dic = @{}.mutableCopy;

            [obj enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, __kindof NSObject * _Nonnull obj, BOOL * _Nonnull stop) {
            
                NSString *newKey = [@[keyHead, key] componentsJoinedByString:@"."];
                dic[newKey] = obj;
                
            }];
            
            [returnResult addObject:dic];
            
        }];
        
        return returnResult;
        
    }
    
    NSString *localKey = key;
    
    if ([key isEqualToString:@"id"]) localKey = @"xid";
    if ([key isEqualToString:@"ts"]) localKey = @"deviceTs";
    
    if ([key hasSuffix:RELATIONSHIP_SUFFIX]) {
        
        NSUInteger substringIndex = key.length - RELATIONSHIP_SUFFIX.length;
        
        if ([relationships objectForKey:[key substringToIndex:substringIndex]]) {
            localKey = [key substringToIndex:substringIndex];
        }
        
    }
    
    if (![properties objectForKey:localKey]) {
        
        NSLog(@"%@ have no property %@", entityName, localKey);
        return nil;
        
    }
    
    BOOL isAttribute = [attributes objectForKey:localKey] ? YES : NO;
    BOOL isRelationship = [relationships objectForKey:localKey] ? YES : NO;
    
    if (!isAttribute && !isRelationship) {
        
        NSLog(@"%@ unknown kind of property %@", entityName, localKey);
        return nil;
        
    }
    
    return [self subpredicatesDicsForArguments:filterArguments
                                      localKey:localKey
                                   isAttribute:isAttribute
                                isRelationship:isRelationship
                                    entityName:entityName
                                    attributes:attributes
                                 relationships:relationships];
    
}

- (STMScriptMessagingFiltersArray *)subpredicatesDicsForArguments:(STMScriptMessagingFilterDictionary *)arguments
                                                         localKey:(NSString *)localKey
                                                      isAttribute:(BOOL)isAttribute
                                                   isRelationship:(BOOL)isRelationship
                                                       entityName:(NSString *)entityName
                                                       attributes:(NSDictionary <NSString *, NSAttributeDescription *> *)attributes
                                                    relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships {

    NSMutableArray <STMScriptMessagingFilterDictionary *> *subpredicatesDics = @[].mutableCopy;
    
    for (NSString *compOp in arguments.allKeys) {
        
        STMScriptMessagingFilterDictionary *subpredicateDic =
            [self subpredicateDicForParams:compOp
                                 arguments:arguments
                                  localKey:localKey
                               isAttribute:isAttribute
                            isRelationship:isRelationship
                                entityName:entityName
                                attributes:attributes
                             relationships:relationships];
        
        if (subpredicateDic) {
            
            [subpredicatesDics addObject:subpredicateDic];
            
        }
        
    }
    
    return subpredicatesDics.copy;
    
}

- (STMScriptMessagingFilterDictionary *)subpredicateDicForParams:(NSString *)compOp
                                                       arguments:(STMScriptMessagingFilterDictionary *)arguments
                                                        localKey:(NSString *)localKey
                                                     isAttribute:(BOOL)isAttribute
                                                  isRelationship:(BOOL)isRelationship
                                                      entityName:(NSString *)entityName
                                                      attributes:(NSDictionary <NSString *, NSAttributeDescription *> *)attributes
                                                   relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships {

    if (![[self comparisonOperators] containsObject:compOp.lowercaseString]) {
        
        NSLog(@"comparison operator should be '==', '!=', '>=', '<=', '>', '<', 'like' or 'likei', not %@", compOp);
        return nil;
        
    }
    
    id value = arguments[compOp];
    
    if ([localKey.lowercaseString hasSuffix:@"uuid"] || [localKey.lowercaseString hasSuffix:@"xid"] || isRelationship) {
        
        if ([value isKindOfClass:[NSString class]]) {
            value = [value stringByReplacingOccurrencesOfString:@"-" withString:@""];
        } else if ([value isEqual:[NSNull null]]) {
            value = nil;
        } else {
            NSLog(@"value is neither a String nor Null, but it should be to get xid or uuid value");
            return nil;
        }
        
    }
    
    if (isAttribute) {
        
        NSString *className = attributes[localKey].attributeValueClassName;
        
        if (!className) {
            
            
            NSLog(@"%@ have no class type for key %@", entityName, localKey);
//            return nil;
            className = NSStringFromClass(NSString.class);
        }
        
        value = [self normalizeValue:value className:className];
        
    } else if (isRelationship) {
        
        if (relationships[localKey].toMany) {
            
            NSLog(@"relationship %@ is toMany", localKey);
            return nil;
            
        }
        
        NSString *className = relationships[localKey].destinationEntity.name;
        
        if (!className) {
            
            NSLog(@"%@ have no class type for key %@", entityName, localKey);
            return nil;
            
        }
        
        value = value ? [STMFunctions dataFromString:value] : nil;
        
        localKey = [localKey stringByAppendingString:@".xid"];
        
    }
    
    NSString *subpredicateString = @"";
    __kindof NSObject *argument = [NSNull null];
    
    if ([value isKindOfClass:[NSString class]]) {
//        value = [(NSString *)value stringByRemovingPercentEncoding];
    }
    
    compOp = compOp.lowercaseString;
    
    if ([compOp hasPrefix:@"like"]) {
        
        if ([compOp hasSuffix:@"i"]) compOp = @"like[cd]";
        if (value) value = [(NSString *)value stringByReplacingOccurrencesOfString:@"%" withString:@"*"];
        
    }
    
    if (value) {
        
        subpredicateString = [NSString stringWithFormat:@"%@ %@ %%@", localKey, compOp];
        argument = value;
        
    } else {
        
        subpredicateString = [NSString stringWithFormat:@"%@ %@ nil", localKey, compOp];
        
    }
    
    return @{subpredicateString : argument};
    
}

- (id)normalizeValue:(id)value className:(NSString *)className {
    
    if (!value) return nil;
    
    if ([value isKindOfClass:[NSNumber class]]) value = [value stringValue];
    
    if ([className isEqualToString:NSStringFromClass([NSNumber class])]) {
        
        return [[[NSNumberFormatter alloc] init] numberFromString:value];
        
    } else if ([className isEqualToString:NSStringFromClass([NSDate class])]) {
        
        return [STMFunctions dateFromString:value];
        
    } else if ([className isEqualToString:NSStringFromClass([NSData class])]) {
        
        return [STMFunctions dataFromString:value];
        
    } else {
        
        return value;
        
    }
    
}

- (STMScriptMessagingFiltersArray *)anyConditionForKey:(NSString *)key
                                       filterArguments:(STMScriptMessagingWhereFilterDictionary *)filterArguments
                                         relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships
                                            entityName:(NSString *)entityName {

    NSString *checkingProperty = [key componentsSeparatedByString:@" "].lastObject;
    
    if (![relationships objectForKey:checkingProperty]) {
        
        NSLog(@"%@ have no property %@ to make ANY predicate", entityName, checkingProperty);
        return nil;
        
    }
    
    if (![filterArguments isKindOfClass:[self whereFilterClass]]) {
        
        NSLog(@"ANY filter is malformed: %@", filterArguments);
        return nil;
        
    }
    
    NSRelationshipDescription *relationship = relationships[checkingProperty];
    
    if (relationship.isToMany && filterArguments.count > 1) {
        
        NSLog(@"WARNING! ANY with more than one condition are broken for to-many relationships");
    
#warning ANY with more than one condition are broken for to-many relationships
        // ANY (rel.a = %a && rel.b = %b)
        // will be transform to
        // ANY rel.a = %a && ANY rel.b = %b
        // which is not equal to first one if rel is to-many

    }
    
    NSString *destinationEntityName = relationship.destinationEntity.name;
    
    STMScriptMessagingFiltersArray *subpredicatesDics =
        [self subpredicatesDicsForEntityName:destinationEntityName
                            filterDictionary:filterArguments];

    STMScriptMessagingFiltersMutableArray *resultSubpredicatesDics = @[].mutableCopy;
    
    [subpredicatesDics enumerateObjectsUsingBlock:^(STMScriptMessagingFilterDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
    
        NSString *firstKey = obj.allKeys.firstObject;
        NSString *finalKey = [@[key, firstKey] componentsJoinedByString:@"."];
        
        [resultSubpredicatesDics addObject:@{finalKey : obj[firstKey]}];
        
    }];
    
    return resultSubpredicatesDics.copy;
    
}

- (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    if (bundleId && error) {
        *error = [NSError errorWithDomain:bundleId
                                     code:1
                                  userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    }
    
    return error == nil;
    
}


@end
