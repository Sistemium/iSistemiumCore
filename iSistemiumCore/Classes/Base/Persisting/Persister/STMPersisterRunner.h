//
//  STMPersisterRunner.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingRunning.h"

@interface STMPersisterRunner : NSOperationQueue <STMPersistingRunning>

- (instancetype)initWithModellingDelegate:(id <STMModelling>)modellingDelegate;

@end
