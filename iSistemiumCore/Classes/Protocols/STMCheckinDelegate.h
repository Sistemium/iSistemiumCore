//
//  STMCheckinDelegate.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 10/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMCheckinDelegate <NSObject>

- (void)getCheckinLocation:(NSDictionary *)checkinLocation;
- (void)checkinLocationError:(NSString *)errorString;


@end
