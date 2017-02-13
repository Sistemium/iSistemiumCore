//
//  STMDefantomizingOwner.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDefantomizingOwner <NSObject>

- (void)defantomizeObject:(NSDictionary *)fantomDic;

- (void)defantomizingFinished;


@end
