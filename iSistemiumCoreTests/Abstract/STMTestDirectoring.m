//
//  STMTestDirectoring.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 10/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMTestDirectoring.h"
#import "STMFunctions.h"

@implementation STMTestDirectoring

- (NSString *)userDocuments {
    return super.userDocuments == nil ? NSTemporaryDirectory() : super.userDocuments;
}

- (NSString *)sharedDocuments {
    return super.sharedDocuments == nil ? NSTemporaryDirectory() : super.sharedDocuments;
}

- (NSBundle *)bundle {
    // TODO: For fun in the future create a pair of separate test bundles and use it here
    // these bundles will contain test models
    return [STMFunctions currentTestTarget] ? [NSBundle bundleForClass:[self class]] : [NSBundle mainBundle];
}

@end
