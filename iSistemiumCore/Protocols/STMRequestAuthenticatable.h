//
//  STMRequestAuthenticatable.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMRequestAuthenticatable <NSObject>

- (NSURLRequest *) authenticateRequest:(NSURLRequest *)request;


@end