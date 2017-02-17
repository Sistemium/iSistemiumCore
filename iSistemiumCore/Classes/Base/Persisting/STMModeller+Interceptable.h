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

- (NSDictionary *)applyMergeInterceptors:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error;

@end
