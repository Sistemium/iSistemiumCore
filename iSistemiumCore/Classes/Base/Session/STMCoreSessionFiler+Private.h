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


@interface STMCoreSessionFiler()

@property (nonatomic, strong) NSString *org;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *documentsPath;
@property (nonatomic, strong) NSString *orgPath;

@property (nonatomic, weak) id <STMDirectoring> directoring;
@property (nonatomic, weak) NSFileManager *fileManager;

@end
