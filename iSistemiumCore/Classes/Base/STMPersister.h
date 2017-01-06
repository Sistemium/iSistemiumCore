//
//  STMPersister.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisting.h"
#import "STMDocument.h"

@interface STMPersister : NSObject <STMPersisting>

+ (instancetype)initWithDocument:(STMDocument *)stmdocument;

@end
