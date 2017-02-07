//
//  STMDefantomizing.h
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDefantomizingOwner.h"


@protocol STMDefantomizing <NSObject>

@property (nonatomic, weak) id <STMDefantomizingOwner> defantomizingOwner;

- (void)startDefantomization;
- (void)stopDefantomization;

- (void)defantomize:(NSDictionary *)fantomDic
            success:(BOOL)success
         entityName:(NSString *)entityName
             result:(NSDictionary *)result
              error:(NSError *)error;


@end
