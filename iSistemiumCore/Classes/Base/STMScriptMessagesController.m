//
//  STMScriptMessagesController.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 29/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessagesController.h"

#import "STMCoreObjectsController.h"


@implementation STMScriptMessagesController

+ (NSPredicate *)predicateForScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error {
    
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
        
//        body = @{@"entity"   : @"Outlet",
//                 @"where"    : @{
//                         @"ANY outletSalesmanContracts" : @{
//                                 @"salesmanId" : @{
//                                         @"==" : @"00351224-e017-11de-b51c-0026551eee5a"
//                                         }
//                                 }
//                         }
//                 };
        
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

+ (Class)filterClass {
    return [NSDictionary <NSString *, __kindof NSObject *> class];
}

+ (Class)whereFilterClass {
    return [NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> class];
}

+ (NSArray <NSString *> *)comparisonOperators {
    return @[@"==", @"!=", @">=", @"<=", @">", @"<", @"like", @"likei"];
}


+ (NSPredicate *)predicateForEntityName:(NSString *)entityName
                                 filter:(NSDictionary <NSString *, __kindof NSObject *> *)filter
                            whereFilter:(NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *)whereFilter
                                  error:(NSError **)error {
    
    NSMutableDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *filterDictionary = whereFilter ? whereFilter.mutableCopy : @{}.mutableCopy;
    
    for (NSString *key in filter.allKeys) {
        filterDictionary[key] = @{@"==" : filter[key]};
    }
    
    if (filterDictionary.count == 0) return nil;

    NSMutableArray <NSPredicate *> *subpredicates = @[].mutableCopy;

    NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *subpredicatesDics = [self subpredicatesDicsForEntityName:entityName
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

+ (NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *)subpredicatesDicsForEntityName:(NSString *)entityName filterDictionary:(NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *)filterDictionary {
    
    STMEntityDescription *entityDescription = [STMEntityDescription entityForName:entityName inManagedObjectContext: [self document].managedObjectContext];
    
    NSDictionary <NSString *, __kindof NSPropertyDescription *> *properties = entityDescription.propertiesByName;
    NSDictionary <NSString *, NSAttributeDescription *> *attributes = entityDescription.attributesByName;
    NSDictionary <NSString *, NSRelationshipDescription *> *relationships = entityDescription.relationshipsByName;
    
    NSMutableArray <NSDictionary <NSString *, __kindof NSObject *> *> *subpredicatesDics = @[].mutableCopy;
    
    for (NSString *key in filterDictionary.allKeys) {
        
        [subpredicatesDics addObjectsFromArray:[self subpredicatesDicsForFilterKey:key
                                                                  filterDictionary:filterDictionary
                                                                     relationships:relationships
                                                                        attributes:attributes
                                                                        properties:properties
                                                                        entityName:entityName]];

    }
    
    return subpredicatesDics;
    
}

+ (NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *)subpredicatesDicsForFilterKey:(NSString *)key
                                                                             filterDictionary:(NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *)filterDictionary
                                                                                relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships
                                                                                   attributes:(NSDictionary <NSString *, NSAttributeDescription *> *)attributes
                                                                                   properties:(NSDictionary <NSString *, __kindof NSPropertyDescription *> *)properties
                                                                                   entityName:(NSString *)entityName {
    
    if ([key hasPrefix:@"ANY"]) {
        
        return [self anyConditionForKey:key
                       filterDictionary:filterDictionary
                          relationships:relationships
                             entityName:entityName];

    }
    
    NSString *localKey = key;
    
    if ([key isEqualToString:@"id"]) localKey = @"xid";
    if ([key isEqualToString:@"ts"]) localKey = @"deviceTs";
    
    NSString *relKey = @"Id";
    
    if ([key hasSuffix:relKey]) {
        
        NSUInteger substringIndex = key.length - relKey.length;
        
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
    
    NSDictionary <NSString *, __kindof NSObject *> *arguments = filterDictionary[key];
    
    return [self subpredicatesDicsForArguments:arguments
                                      localKey:localKey
                                   isAttribute:isAttribute
                                isRelationship:isRelationship
                                    entityName:entityName
                                    attributes:attributes
                                 relationships:relationships];
    
}

+ (NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *)subpredicatesDicsForArguments:(NSDictionary <NSString *, __kindof NSObject *> *)arguments
                                                                                     localKey:(NSString *)localKey
                                                                                  isAttribute:(BOOL)isAttribute
                                                                               isRelationship:(BOOL)isRelationship
                                                                                   entityName:(NSString *)entityName
                                                                                   attributes:(NSDictionary <NSString *, NSAttributeDescription *> *)attributes
                                                                                relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships {
    
    NSMutableArray <NSDictionary <NSString *, __kindof NSObject *> *> *subpredicatesDics = @[].mutableCopy;
    
    for (NSString *compOp in arguments.allKeys) {
        
        NSDictionary <NSString *, __kindof NSObject *> *subpredicateDic = [self subpredicateDicForParams:compOp
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
    
    return subpredicatesDics;
    
}

+ (NSDictionary <NSString *, __kindof NSObject *> *)subpredicateDicForParams:(NSString *)compOp
                                                                               arguments:(NSDictionary <NSString *, __kindof NSObject *> *)arguments
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
        
        if (![value isKindOfClass:[NSString class]]) {
            
            NSLog(@"value is not a String, but it should be to get xid or uuid value");
            return nil;
            
        }
        
        value = [value stringByReplacingOccurrencesOfString:@"-" withString:@""];
        
    }
    
    if (isAttribute) {
        
        NSString *className = attributes[localKey].attributeValueClassName;
        
        if (!className) {
            
            NSLog(@"%@ have no class type for key %@", entityName, localKey);
            return nil;
            
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
        
        value = [self relationshipObjectForValue:value className:className];
        
    }
    
    NSString *subpredicateString = @"";
    __kindof NSObject *argument = [NSNull null];
    
    if ([value isKindOfClass:[NSString class]]) {
        value = [(NSString *)value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }

    compOp = compOp.lowercaseString;
    
    if ([compOp hasPrefix:@"like"]) {
        
        if ([compOp hasSuffix:@"i"]) compOp = @"like[cd]";
        if (value) value = [NSString stringWithFormat:@"*%@*", value];
        
    }
    
    if (value) {
        
        subpredicateString = [NSString stringWithFormat:@"%@ %@ %%@", localKey, compOp];
        argument = value;
        
    } else {

        subpredicateString = [NSString stringWithFormat:@"%@ %@ nil", localKey, compOp];

    }
    
    return @{subpredicateString : argument};
    
}

+ (id)normalizeValue:(id)value className:(NSString *)className {
    
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

+ (id)relationshipObjectForValue:(id)value className:(NSString *)className {
    
    if (![value isKindOfClass:[NSString class]]) {
        
        NSLog(@"relationship value is not a String, can not get xid");
        return nil;
        
    }
    
    value = [STMCoreObjectsController objectForXid:[STMFunctions dataFromString:value] entityName:className];
    
    return value;
    
}

+ (NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *)anyConditionForKey:(NSString *)key
                                                                  filterDictionary:(NSDictionary <NSString *, NSDictionary <NSString *, __kindof NSObject *> *> *)filterDictionary
                                                                     relationships:(NSDictionary <NSString *, NSRelationshipDescription *> *)relationships
                                                                        entityName:(NSString *)entityName {
    
    NSString *checkingProperty = [key componentsSeparatedByString:@" "].lastObject;
    
    if (![relationships objectForKey:checkingProperty]) {
        
        NSLog(@"%@ have no property %@ to make ANY predicate", entityName, checkingProperty);
        return nil;
        
    }

    NSDictionary <NSString *, __kindof NSObject *> *destinationEntityFilter = filterDictionary[key];
    NSString *firstKey = destinationEntityFilter.allKeys.firstObject;
    destinationEntityFilter = @{firstKey : destinationEntityFilter[firstKey]};     // only one filter is using at ANY condition
    
    if (![destinationEntityFilter isKindOfClass:[self whereFilterClass]]) {
        
        NSLog(@"ANY filter is malformed: %@", destinationEntityFilter);
        return nil;
        
    }

    NSString *destinationEntityName = relationships[checkingProperty].destinationEntity.name;
    
    NSArray <NSDictionary <NSString *, __kindof NSObject *> *> *subpredicatesDics = [self subpredicatesDicsForEntityName:destinationEntityName
                                                                                                      filterDictionary:destinationEntityFilter];

    firstKey = subpredicatesDics.firstObject.allKeys.firstObject;
    NSString *finalKey = [@[key, firstKey] componentsJoinedByString:@"."];
    
    subpredicatesDics = @[@{finalKey : subpredicatesDics.firstObject[firstKey]}];
    
    return subpredicatesDics;
    
}

+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    if (bundleId && error) *error = [NSError errorWithDomain:bundleId
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    
    return (error == nil);
    
}


@end
