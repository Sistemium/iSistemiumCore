//
//  STMCoreSessionFiler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 03/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMFiling.h"


#define SHARED_PATH @"shared"
#define PERSISTENCE_PATH @"persistence"
#define PICTURES_PATH @"pictures"
#define WEBVIEWS_PATH @"webViews"


@interface STMCoreSessionFiler : NSObject <STMDirectoring, STMFiling>

+ (instancetype)coreSessionfilingWithDirectoring:(id <STMDirectoring>)directoring;

- (instancetype)initWithOrg:(NSString *)org
                     userId:(NSString *)uid;

@end
