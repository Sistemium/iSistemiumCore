//
//  STMSocketTransport+Persisting.h
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport.h"
#import "STMPersistingWithHeadersAsync.h"

static NSString *kSocketFindAllMethod = @"findAll";
static NSString *kSocketFindMethod = @"find";
static NSString *kSocketUpdateMethod = @"update";
static NSString *kSocketDestroyMethod = @"destroy";

@interface STMSocketTransport (Persisting)  <STMPersistingWithHeadersAsync>

@end
