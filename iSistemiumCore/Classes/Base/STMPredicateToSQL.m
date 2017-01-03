//
//  STMPredicateToSQL.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPredicateToSQL.h"
#import "STMFmdb.h"
#import "STMFunctions.h"

@implementation STMPredicateToSQL

static NSString *SQLNullValueString = @"NULL";

static STMPredicateToSQL *sharedInstance;

+ (STMPredicateToSQL *) sharedInstance{
    return sharedInstance;
}

+ (void) initialize{
    sharedInstance = [STMPredicateToSQL new];
}

- (NSString *)SQLExpressionForKeyPath:(NSString *)keyPath{
    NSString     *retStr = nil;
    NSDictionary *convertibleSetOperations = @{@"@avg" : @"avg",@"@max" : @"max",@"@min" : @"min",@"@sum" : @"sum",@"@distinctUnionOfObjects" : @"distinct" };
    
    for (NSString *setOpt in [convertibleSetOperations allKeys]){
        if ([keyPath hasSuffix:setOpt]){
            NSString *clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
            retStr = [NSString stringWithFormat:@"%@(%@)",convertibleSetOperations[setOpt], clean];
        }
    }
    if (retStr != nil) {
        return retStr;
    }
    return keyPath;
}

- (NSString *) SQLSelectClauseForSubqueryExpression:(NSExpression *)expression{
    NSLog(@"SQLSelectClauseForSubqueryExpression not implemented");
    return nil;
}

- (NSString *) SQLLiteralListForArray:(NSArray *)array{
    NSMutableArray *retArray = [NSMutableArray array];
    
    for (NSExpression *obj in array) {
        [retArray addObject:[self SQLExpressionForNSExpression:obj]];
    }
    return [NSString stringWithFormat:@"(%@)",[retArray componentsJoinedByString:@","]];
}

- (NSString *) SQLFunctionLiteralForFunctionExpression:(NSExpression *)exp{
    NSDictionary *convertibleNullaryFunctions = @{ @"now" : @"date('now')",@"random" : @"random()" };
    NSDictionary *convertibleUnaryFunctions   = @{ @"uppercase:" : @"upper",@"lowercase:" : @"lower",@"abs:" : @"abs" };
    NSDictionary *convertibleBinaryFunctions  = @{ @"add:to:"        : @"+" ,
                                                   @"from:subtract:" : @"-" ,
                                                   @"multiply:by:"   : @"*" ,
                                                   @"divide:by:"     : @"/" ,
                                                   @"modulus:by:"    : @"%" ,
                                                   @"leftshift:by"   : @"<<",
                                                   @"rightshift:by:" : @">>"
                                                   };
    
    if ([[convertibleNullaryFunctions allKeys] containsObject:[exp function]]){
        return convertibleNullaryFunctions[[exp function]];
    }
    else {
        if ([[convertibleUnaryFunctions allKeys] containsObject:[exp function]]){
            return [NSString stringWithFormat:@"%@(%@)",convertibleUnaryFunctions[[exp function]],[self SQLExpressionForNSExpression:[exp arguments][0]]];
        }
        else {
            if ([[convertibleBinaryFunctions allKeys] containsObject:[exp function]]){
                return ([NSString stringWithFormat:@"(%@ %@ %@)",[self SQLExpressionForNSExpression:[exp arguments][0]],convertibleBinaryFunctions[[exp function]],[self SQLExpressionForNSExpression:[exp arguments][1]]]);
            }
            else {
                NSLog(@"SQLFunctionLiteralForFunctionExpression could not be converted because it uses an unconvertible function");
            }
        }
    }
    return nil;
}

- (NSString *) SQLNamedReplacementVariableForVariable:(NSString *)var{
    return var;
}


- (NSString *)DatabaseKeyfor:(NSString *)obj{
    bool isTable = [[STMFmdb sharedInstance] containstTableWithNameWithName:[STMFunctions uppercaseFirst:obj]];
    if (isTable) {
        return [STMFunctions uppercaseFirst:obj];
    }
    return obj ;
}

- (NSString *)ToManyKeyToTablename:(NSString *)obj{
    bool isTable = [[STMFmdb sharedInstance] containstTableWithNameWithName:[STMFunctions uppercaseFirst:[obj substringToIndex:[obj length] - 1]]];
    if (isTable) {
        return [STMFunctions uppercaseFirst:[obj substringToIndex:[obj length] - 1]];
    }
    return obj ;
}

- (NSString *)FKToTablename:(NSString *)obj{
    bool isTable = [[STMFmdb sharedInstance] containstTableWithNameWithName:[STMFunctions uppercaseFirst:obj]];
    if (isTable) {
        return [obj stringByAppendingString:@"Id"];
    }
    return obj ;
}

- (NSString *)SQLExpressionForLeftKeyPath:(NSString *)keyPath{
    NSString *retStr = nil;
    NSDictionary *convertibleSetOperations = @{ @"@avg" : @"avg",@"@max" : @"max",@"@min" : @"min",@"@sum" : @"sum",@"@distinctUnionOfObjects" : @"distinct" };
    
    for (NSString *setOpt in [convertibleSetOperations allKeys]){
        if ([keyPath hasSuffix:setOpt]){
            NSString *clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
            retStr = [NSString stringWithFormat:@"%@(%@)",convertibleSetOperations[setOpt],clean];
        }
    }
    
    if (retStr != nil) {
        return [self FKToTablename:retStr];
    }
    return [self FKToTablename:keyPath];
}


- (NSString *) SQLConstantForLeftValue:(id) val{
    if (val == nil) {
        return SQLNullValueString;
    }
    if ([val isEqual:[NSNull null]]) {
        return SQLNullValueString;
    }
    
    if ([val isKindOfClass:[NSString class]]){
        return [self FKToTablename:val];
    }
    else {
        if ([val respondsToSelector:@selector(intValue)]){
            return [self FKToTablename:[val stringValue]];
        }
        else {
            return [self SQLConstantForLeftValue:[val description]];
        }
    };
    return nil;
}



-(NSString *)SQLExpressionForLeftNSExpression:(NSExpression *)expression{
    NSString *retStr = nil;
    
    switch ([expression expressionType]){
        case NSConstantValueExpressionType: {
            retStr = [self SQLConstantForLeftValue:[expression constantValue]];
            break;
        }
        case NSVariableExpressionType: {
            retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
            break;
        }
        case NSKeyPathExpressionType: {
            retStr = [self SQLExpressionForLeftKeyPath:[expression keyPath]];
            break;
        }
        case NSFunctionExpressionType: {
            retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
            break;
        }
        case NSSubqueryExpressionType: {
            retStr = [self SQLSelectClauseForSubqueryExpression:expression];
            break;
        }
        case NSAggregateExpressionType: {
            retStr = [self SQLLiteralListForArray:[expression collection]];
            break;
        }
        case NSUnionSetExpressionType: {
            break;
        }
        case NSIntersectSetExpressionType: {
            break;
        }
        case NSMinusSetExpressionType: {
            break;
        }
        case NSEvaluatedObjectExpressionType: {
            break;
        }
        case NSBlockExpressionType: {
            break;
        }
        default:{
            break;
        }
    }
    return retStr;
}

-(NSString *)SQLConstantForValue:(id) val{
    if (val == nil) {
        return SQLNullValueString;
    }
    if ([val isEqual:[NSNull null]]) {
        return SQLNullValueString;
    }
    if ([val isKindOfClass:[NSString class]]){
        return val;
    }
    if ([val isKindOfClass:[NSData class]]){
        return [[STMFunctions UUIDStringFromUUIDData:val] lowercaseString];
    }
    else {
        if ([val respondsToSelector:@selector(intValue)]){
            return [val stringValue];
        }
        else {
            return [self SQLConstantForValue:[val description]];
        }
    }
    return nil;
}



-(NSString *)SQLExpressionForNSExpression:(NSExpression *)expression{
    NSString *retStr = nil;
    
    switch ([expression expressionType]){
        case NSConstantValueExpressionType: {
            retStr = [self SQLConstantForValue:[expression constantValue]];
            break;
        }
        case NSVariableExpressionType: {
            retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
            break;
        }
        case NSKeyPathExpressionType: {
            retStr = [self SQLExpressionForKeyPath:[expression keyPath]];
            break;
        }
        case NSFunctionExpressionType: {
            retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
            break;
        }
        case NSSubqueryExpressionType: {
            retStr = [self SQLSelectClauseForSubqueryExpression:expression];
            break;
        }
        case NSAggregateExpressionType: {
            retStr = [self SQLLiteralListForArray:[expression collection]];
            break;
        }
        case NSUnionSetExpressionType: {
            break;
        }
        case NSIntersectSetExpressionType: {
            break;
        }
        case NSMinusSetExpressionType: {
            break;
        }
        case NSEvaluatedObjectExpressionType: {
            break;
        }
        case NSBlockExpressionType: {
            break;
        }
        default:{
            break;
        }
    }
    return retStr;
}

- (NSString *) SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate{
    
    NSString *leftSQLExpression  = [self SQLExpressionForLeftNSExpression:[predicate leftExpression]];
    NSString *rightSQLExpression = [self SQLExpressionForNSExpression:[predicate rightExpression]];
    
    rightSQLExpression = [NSString stringWithFormat:@"'%@'",rightSQLExpression];
    
    NSArray* tables = [leftSQLExpression componentsSeparatedByString:@"."];
    
    NSMutableArray<NSString*>* mtables = tables.mutableCopy;
    
    for (int i=0; i < [mtables count]; i++){
        if ([mtables[i] isEqualToString:@"xid"]){
            mtables[i] = @"id";
        }
    }
             
    tables = mtables.copy;
    
    if (tables.count > 1){
        leftSQLExpression = [NSString stringWithFormat:@"exists ( select * from %@ where %@",[self ToManyKeyToTablename:[self DatabaseKeyfor:tables[0]]],[self FKToTablename:tables[1]]];
        if ([[self ToManyKeyToTablename:tables[0]] isEqualToString:tables[0]]){
            rightSQLExpression = [rightSQLExpression stringByAppendingString:[NSString stringWithFormat:@" and id = %@Id )",tables[0]]];
        }else{
            rightSQLExpression = [rightSQLExpression stringByAppendingString:@" and ?uncapitalizedTableName?Id = ?capitalizedTableName?.id )"];
        }
    }
    
    
    
    switch ([predicate predicateOperatorType]){
        case NSLessThanPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ < %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSLessThanOrEqualToPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ <= %@)",leftSQLExpression,rightSQLExpression] ;
        }
        case NSGreaterThanPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ > %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSGreaterThanOrEqualToPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ >= %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSEqualToPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ = %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSNotEqualToPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ <> %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSMatchesPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ MATCH %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSInPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ IN %@)",leftSQLExpression,rightSQLExpression];
        }
        case NSBetweenPredicateOperatorType: {
            return [NSString stringWithFormat:@"(%@ BETWEEN '%@' AND '%@')",[self SQLExpressionForLeftNSExpression:[predicate leftExpression]],
                                                       [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][0]],
                                                       [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][1]]] ;
        }
        case NSLikePredicateOperatorType:
        case NSContainsPredicateOperatorType: {
            return([NSString stringWithFormat:@"(%@ LIKE %%%@%%)",leftSQLExpression,rightSQLExpression]);
        }
        case NSBeginsWithPredicateOperatorType: {
            return([NSString stringWithFormat:@"(%@ LIKE %@%%)",leftSQLExpression,rightSQLExpression]);
        }
        case NSEndsWithPredicateOperatorType: {
            return([NSString stringWithFormat:@"(%@ LIKE %%%@)",leftSQLExpression,rightSQLExpression]);
        }
        case NSCustomSelectorPredicateOperatorType: {
            NSLog(@"SQLWhereClauseForComparisonPredicate custom selectors are not supported");
            break;
        }
    }
    
    return nil;
}

- (NSString *) SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate{
    NSMutableArray *subs = [NSMutableArray array];
    
    for (NSPredicate *sub in [predicate subpredicates]) {
        [subs addObject:[self SQLFilterForPredicate:sub]];
    }
    
    if (subs.count == 1){
        return subs[0];
    }
    
    NSString *conjunction;
    switch ([(NSCompoundPredicate *)predicate compoundPredicateType]){
        case NSAndPredicateType: {
            conjunction = @" AND ";
            break;
        }
        case NSOrPredicateType: {
            conjunction = @" OR ";
            break;
        }
        case NSNotPredicateType: {
            conjunction = @" NOT ";
            break;
        }
        default: {
            conjunction = @" ";
            break;
        }
    }
    
    return [NSString stringWithFormat:@"(%@)", [subs componentsJoinedByString:conjunction]];
}

- (NSString *)SQLFilterForPredicate:(NSPredicate *)predicate{
    if ([predicate respondsToSelector:@selector(compoundPredicateType)]){
        return [self SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate];
    }
    else {
        if ([predicate respondsToSelector:@selector(predicateOperatorType)]){
            return [self SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate];
        }
        else {
            NSLog(@"SQLFilterForPredicate predicate is not of a convertible class");
        }
    }
    return nil;
}

@end
