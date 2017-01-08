//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersister.h"

@interface STMPersister()

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, strong) STMDocument *document;

@end

@implementation STMPersister

@synthesize document;

+ (instancetype)initWithDocument:(STMDocument *)stmdocument forSession:(id<STMSession>)session {
    
    STMPersister *persister = [[STMPersister alloc] init];
    
    persister.session = session;
    persister.document = stmdocument;
    
    return persister;
}


#pragma mark - STMPersistingSync


#pragma mark - STMPersistingAsync


#pragma mark - STMPersistingPromised


@end
