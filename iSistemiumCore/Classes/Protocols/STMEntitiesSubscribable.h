//
//  STMEntitiesSubscribable.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMEntitiesSubscribable <NSObject>

- (void)subscribedEntitiesObjectWasReceived:(NSDictionary *)objectDic;


@end
