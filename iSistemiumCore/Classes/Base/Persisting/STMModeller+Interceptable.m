//
//  STMModeller+Interceptable.m
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller+Interceptable.h"
#import "STMModeller+Private.h"

@implementation STMModeller (Interceptable)

- (void)beforeMergeEntityName:(NSString *)entityName interceptor:(id <STMPersistingMergeInterceptor>)interceptor {
    
    if (interceptor) {
        [self.beforeMergeInterceptors setObject:interceptor forKey:entityName];
    } else {
        [self.beforeMergeInterceptors removeObjectForKey:entityName];
    }
    
}

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    id <STMPersistingMergeInterceptor> interceptor = [self.beforeMergeInterceptors objectForKey:entityName];
    
    if (!interceptor) return attributes;
    
    return [interceptor interceptedAttributes:attributes options:options error:error];
    
}

@end
