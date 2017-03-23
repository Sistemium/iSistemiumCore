//
//  STMCoreSessionFiler+Private.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 06/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSessionFiler.h"

#define SHARED_PATH @"shared"
#define PERSISTENCE_PATH @"persistence"
#define PICTURES_PATH @"pictures"
#define WEBVIEWS_PATH @"webViews"

#define ATTRIBUTE_FILE_PROTECTION_NONE NSFileProtectionKey:NSFileProtectionNone

@interface STMCoreSessionFiler()

@property (nonatomic, strong) NSString *userDocuments;
@property (nonatomic, strong) NSString *sharedDocuments;

//@property (nonatomic, strong) id <STMDirectoring> directoring;

@end
