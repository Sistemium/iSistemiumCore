//
//  STMSocketConnectionOwner.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMSocketConnectionOwner <NSObject>

- (NSTimeInterval)timeout;

- (void)socketAuthorizationError:(NSError *)error;
- (void)socketReceiveAuthorization;
- (void)socketWillClosed;
- (void)socketLostConnection;


@end
