//
//  STMPersistingInterceptorUniqueProperty.h
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMPersistingIntercepting.h"

@interface STMPersistingInterceptorUniqueProperty : STMCoreController <STMPersistingMergeInterceptor>

@property (nonatomic, strong) NSString *entityName;
@property (nonatomic, strong) NSString *propertyName;

@end
