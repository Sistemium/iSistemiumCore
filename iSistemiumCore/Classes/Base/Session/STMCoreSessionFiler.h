//
//  STMCoreSessionFiler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 03/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFiling.h"

// TODO: split away with STMDirectoring implementation, then rename to STMFiler because there's nothing about sessions here

@interface STMCoreSessionFiler : NSObject <STMDirectoring, STMFiling>

+ (instancetype)coreSessionFilerWithDirectoring:(id <STMDirectoring>)directoring;

- (instancetype)initWithOrg:(NSString *)org
                     userId:(NSString *)uid;

+ (NSDictionary *)JSONOfAllFiles;

+ (NSDictionary *)JSONOfFilesAtPath:(NSString *)path;

@end
