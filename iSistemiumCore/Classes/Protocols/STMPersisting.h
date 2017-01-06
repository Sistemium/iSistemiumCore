//
//  STMPersisting.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMPersistingPromised.h"
#import "STMDocument.h"

@protocol STMPersisting <STMPersistingSync,STMPersistingAsync,STMPersistingPromised>

#warning make private
@property (nonatomic, strong) STMDocument *document;

@end
