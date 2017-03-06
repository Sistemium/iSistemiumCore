//
//  STMModeller+Interceptable.m
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller+Interceptable.h"
#import "STMModeller+Private.h"
#import "STMFunctions.h"

@implementation STMModeller (Interceptable)

- (void)beforeMergeEntityName:(NSString *)entityName interceptor:(id <STMPersistingMergeInterceptor>)interceptor {
    
    if (interceptor) {
        [self.beforeMergeInterceptors setObject:interceptor forKey:entityName];
    } else {
        [self.beforeMergeInterceptors removeObjectForKey:entityName];
    }
    
}

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {

    NSObject <STMPersistingMergeInterceptor> *interceptor = [self.beforeMergeInterceptors objectForKey:entityName];
    
    if (!interceptor) return attributes;
    
    if ([interceptor respondsToSelector:@selector(interceptedAttributes:options:error:)]) {
        return [interceptor interceptedAttributes:attributes options:options error:error];
    }
    
    return attributes;
    
}

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inTransaction:(id<STMPersistingTransaction>)transaction {
    
    NSObject <STMPersistingMergeInterceptor> *interceptor = [self.beforeMergeInterceptors objectForKey:entityName];
    
    if (!interceptor) return attributes;
    
    if ([interceptor respondsToSelector:@selector(interceptedAttributes:options:error:inTransaction:)]) {
        return [interceptor interceptedAttributes:attributes options:options error:error inTransaction:transaction];
    }
    
    return attributes;
    
}

- (NSArray *)applyMergeInterceptors:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError **)error {
    
    NSObject <STMPersistingMergeInterceptor> *interceptor = [self.beforeMergeInterceptors objectForKey:entityName];
    
    if (!interceptor) return attributeArray;
    
    if ([interceptor respondsToSelector:@selector(interceptedAttributeArray:options:error:)]) {
        
        return [interceptor interceptedAttributeArray:attributeArray options:options error:error];
        
    } else if ([interceptor respondsToSelector:@selector(interceptedAttributes:options:error:)]) {
        
        return [STMFunctions mapArray:attributeArray withBlock:^id(NSDictionary *attributes) {
            return *error ? nil : [interceptor interceptedAttributes:attributes options:options error:error];
        }];
        
    }
    
    return attributeArray;
    
}

@end
