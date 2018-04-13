//
//  STMModeller+Interceptable.h
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller.h"
#import "STMPersistingIntercepting.h"

@interface STMModeller (Interceptable) <STMPersistingIntercepting>

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName
                              attributes:(NSDictionary *)attributes
                                 options:(NSDictionary *)options
                                   error:(NSError **)error;

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName
                              attributes:(NSDictionary *)attributes
                                 options:(NSDictionary *)options
                                   error:(NSError **)error
                           inTransaction:(id <STMPersistingTransaction>)transaction;

- (NSArray *)applyMergeInterceptors:(NSString *)entityName
                     attributeArray:(NSArray *)attributeArray
                            options:(NSDictionary *)options
                              error:(NSError **)error;

@end
