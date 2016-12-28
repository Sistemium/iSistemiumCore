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
    
    for (NSString *setOpt in [convertibleSetOperations allKeys])
    { if ([keyPath hasSuffix:setOpt])
    { NSString *clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
        retStr = [NSString stringWithFormat:@"%@(%@)",convertibleSetOperations[setOpt], clean];
    };
    };
    if (retStr != nil) return(retStr);
    return(keyPath);
}

- (NSString *) SQLSelectClauseForSubqueryExpression:(NSExpression *)expression{
    NSLog(@"SQLSelectClauseForSubqueryExpression not implemented");
    return(nil);
}

- (NSString *) SQLLiteralListForArray:(NSArray *)array{
    NSMutableArray *retArray = [NSMutableArray array];
    
    for (NSExpression *obj in array) { [retArray addObject:[self SQLExpressionForNSExpression:obj]]; };
    return([NSString stringWithFormat:@"(%@)",[retArray componentsJoinedByString:@","]]);
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
    
    if ([[convertibleNullaryFunctions allKeys] containsObject:[exp function]])
    { return(convertibleNullaryFunctions[[exp function]]);
    }
    else { if ([[convertibleUnaryFunctions allKeys] containsObject:[exp function]])
    { return([NSString stringWithFormat:@"%@(%@)",convertibleUnaryFunctions[[exp function]],[self SQLExpressionForNSExpression:[exp arguments][0]]]);
    }
    else { if ([[convertibleBinaryFunctions allKeys] containsObject:[exp function]])
    { return([NSString stringWithFormat:@"(%@ %@ %@)",[self SQLExpressionForNSExpression:[exp arguments][0]],convertibleBinaryFunctions[[exp function]],[self SQLExpressionForNSExpression:[exp arguments][1]]]);
    }
    else { NSLog(@"SQLFunctionLiteralForFunctionExpression could not be converted because it uses an unconvertible function");
    };
    };
    };
    return(nil);
}

- (NSString *) SQLNamedReplacementVariableForVariable:(NSString *)var{
    return(var);
}


- (NSString *)DatabaseKeyfor:(NSString *)obj{
    NSArray *keysForObj = [[STMFmdb sharedInstance] allKeysForObject:obj];
    if ([keysForObj count] > 0) return([keysForObj objectAtIndex:0]);
    return(obj);
}



- (NSString *)SQLExpressionForLeftKeyPath:(NSString *)keyPath{
    NSString     *retStr = nil;
    NSDictionary *convertibleSetOperations = @{ @"@avg" : @"avg",@"@max" : @"max",@"@min" : @"min",@"@sum" : @"sum",@"@distinctUnionOfObjects" : @"distinct" };
    
    for (NSString *setOpt in [convertibleSetOperations allKeys])
    { if ([keyPath hasSuffix:setOpt])
    { NSString *clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
        retStr = [NSString stringWithFormat:@"%@(%@)",convertibleSetOperations[setOpt],clean];
    };
    };
    
    if (retStr != nil) return([self DatabaseKeyfor:retStr]);
    return([self DatabaseKeyfor:keyPath]);
}


- (NSString *) SQLConstantForLeftValue:(id) val{
    if (val == nil) return(SQLNullValueString);
    if ([val isEqual:[NSNull null]]) return(SQLNullValueString);
    
    if ([val isKindOfClass:[NSString class]])
    { //PSLog(@"SQLConstantForLeftValue val %@",val);
        return([self DatabaseKeyfor:val]);
    }
    else { if ([val respondsToSelector:@selector(intValue)])
    { return([self DatabaseKeyfor:[val stringValue]]);
    }
    else { return([self SQLConstantForLeftValue:[val description]]);
    };
    };
    return(nil);
}



-(NSString *)SQLExpressionForLeftNSExpression:(NSExpression *)expression{
    NSString *retStr = nil;
    
    switch ([expression expressionType])
    { case NSConstantValueExpressionType: { retStr = [self SQLConstantForLeftValue:[expression constantValue]];
        //NSLog(@"LEFT  NSConstantValueExpressionType %@",retStr); // contains 'Patient Name' etc..
        break; }
        case NSVariableExpressionType: { retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
            //NSLog(@"LEFT NSVariableExpressionType %@",retStr);
            break; }
        case NSKeyPathExpressionType: { retStr = [self SQLExpressionForLeftKeyPath:[expression keyPath]];
            //NSLog(@"LEFT NSKeyPathExpressionType %@",retStr); // first "Patient Name'
            break; }
        case NSFunctionExpressionType: { retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
            //NSLog(@"LEFT NSFunctionExpressionType %@",retStr);
            break; }
        case NSSubqueryExpressionType: { retStr = [self SQLSelectClauseForSubqueryExpression:expression];
            //NSLog(@"LEFT NSSubqueryExpressionType %@",retStr);
            break; }
        case NSAggregateExpressionType: { retStr = [self SQLLiteralListForArray:[expression collection]];
            //NSLog(@"LEFT NSAggregateExpressionType %@",retStr);
            break; }
        case NSUnionSetExpressionType: { break; }
        case NSIntersectSetExpressionType: { break; }
        case NSMinusSetExpressionType: { break; }
            
        case NSEvaluatedObjectExpressionType: { break; } // these can't be converted
        case NSBlockExpressionType: { break; }
            //case NSAnyKeyExpressionType: { break; }
        default:
            break;
    };
    return retStr;
}



-(NSString *)SQLConstantForValue:(id) val{
    if (val == nil) return(SQLNullValueString);
    if ([val isEqual:[NSNull null]]) return(SQLNullValueString);
    
    if ([val isKindOfClass:[NSString class]])
    { //NSLog(@"SQLConstantForValue val %@",val);
        return(val);
    }
    else { if ([val respondsToSelector:@selector(intValue)])
    { return([val stringValue]);
    }
    else { return([self SQLConstantForValue:[val description]]);
    };
    };
    return(nil);
}



-(NSString *)SQLExpressionForNSExpression:(NSExpression *)expression{
    NSString *retStr = nil;
    
    switch ([expression expressionType])
    { case NSConstantValueExpressionType: { retStr = [self SQLConstantForValue:[expression constantValue]];
        //NSLog(@"NSConstantValueExpressionType %@",retStr); // contains 'Patient Name' etc..
        break; }
        case NSVariableExpressionType: { retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
            //NSLog(@"NSVariableExpressionType %@",retStr);
            break; }
        case NSKeyPathExpressionType: { retStr = [self SQLExpressionForKeyPath:[expression keyPath]];
            //NSLog(@"NSKeyPathExpressionType %@",retStr);
            break; }
        case NSFunctionExpressionType: { retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
            //NSLog(@"NSFunctionExpressionType %@",retStr);
            break; }
        case NSSubqueryExpressionType: { retStr = [self SQLSelectClauseForSubqueryExpression:expression];
            //NSLog(@"NSSubqueryExpressionType %@",retStr);
            break; }
        case NSAggregateExpressionType: { retStr = [self SQLLiteralListForArray:[expression collection]];
            //PSLog(@"NSAggregateExpressionType %@",retStr);
            break; }
        case NSUnionSetExpressionType: { break; }
        case NSIntersectSetExpressionType: { break; }
        case NSMinusSetExpressionType: { break; }
            
        case NSEvaluatedObjectExpressionType: { break; } // these can't be converted
        case NSBlockExpressionType: { break; }
            //case NSAnyKeyExpressionType: { break; }
        default:
            break;
    };
    return retStr;
}

- (NSString *) SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate{
    NSString *leftSQLExpression  = [self SQLExpressionForLeftNSExpression:[predicate leftExpression]];
    NSString *rightSQLExpression = [self SQLExpressionForNSExpression:[predicate rightExpression]];
    
    switch ([predicate predicateOperatorType])
    {           case NSLessThanPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ < '%@')",leftSQLExpression,rightSQLExpression]);
        break; }
        case NSLessThanOrEqualToPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ <= '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSGreaterThanPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ > '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSGreaterThanOrEqualToPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ >= '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSEqualToPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ = '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSNotEqualToPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ <> '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSMatchesPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ MATCH '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSInPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ IN '%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSBetweenPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ BETWEEN '%@' AND '%@')",[self SQLExpressionForLeftNSExpression:[predicate leftExpression]],
                                                       [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][0]],
                                                       [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][1]]]);
            break; }
        case NSLikePredicateOperatorType:
        case NSContainsPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ LIKE '%%%@%%')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSBeginsWithPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ LIKE '%@%%')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSEndsWithPredicateOperatorType: { return([NSString stringWithFormat:@"(%@ LIKE '%%%@')",leftSQLExpression,rightSQLExpression]);
            break; }
        case NSCustomSelectorPredicateOperatorType: { NSLog(@"SQLWhereClauseForComparisonPredicate custom selectors are not supported");
            break; }
    };
    
    return(nil);
}

- (NSString *) SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate{
    NSMutableArray *subs = [NSMutableArray array];
    
    for (NSPredicate *sub in [predicate subpredicates]) { [subs addObject:[self SQLFilterForPredicate:sub]]; };
    
    NSString *conjunction;
    switch ([(NSCompoundPredicate *)predicate compoundPredicateType])
    { case NSAndPredicateType: { conjunction = @" AND "; break; }
        case NSOrPredicateType: { conjunction = @" OR ";  break; }
        case NSNotPredicateType: { conjunction = @" NOT "; break; }
        default: { conjunction = @" ";     break; }
    };
    
    return([NSString stringWithFormat:@"(%@)", [subs componentsJoinedByString:conjunction]]);
}

- (NSString *)SQLFilterForPredicate:(NSPredicate *)predicate{
    if ([predicate respondsToSelector:@selector(compoundPredicateType)])
    { return([self SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate]);
    }
    else { if ([predicate respondsToSelector:@selector(predicateOperatorType)])
    { return([self SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate]);
    }
    else { NSLog(@"SQLFilterForPredicate predicate is not of a convertible class");
    }
    };
    return(nil);
}

@end
