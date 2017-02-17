//
//  STMPersistingIntercepting.h
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingMergeInterceptor
    
- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error;
    
@end


@protocol STMPersistingIntercepting

@property (readonly,copy) NSDictionary <NSString *, id> *beforeMergeInterceptors;

- (void)beforeMergeEntityName:(NSString *)entityName interceptor:(id <STMPersistingMergeInterceptor>)interceptor;

@end
