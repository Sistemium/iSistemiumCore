//
//  STMPersistingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFunctions.h"
#import "STMPersistingTests.h"
#import "STMCoreSessionManager.h"
#import "STMCoreAuthController.h"

@interface STMPersistingTests ()

@property (nonatomic) BOOL waitForSession;

@end

@implementation STMPersistingTests

+ (BOOL)needWaitSession {
    return NO;
}

- (void)setUp {

    self.ownerXid = [STMFunctions uuidString];
    self.cleanupPredicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", self.ownerXid];
    
    [super setUp];
    
    if ([STMFunctions.currentTestTarget hasSuffix:@"InMemory"]) {
        NSLog(@"STMPersistingTests will persist to memory!");
        self.fakePersistingOptions = @{STMFakePersistingOptionInMemoryDB};
        self.waitForSession = [self.class needWaitSession] && !self.persister;
    }
    
    // Create an empty FakePersister if there are options
    
    if (self.fakePersistingOptions) {
        [self fakePersistingWithOptions:self.fakePersistingOptions];
    }

    if (self.persister && !self.waitForSession) return;
    
    // Otherwise wait for the session to start and get it's persister if needed
    
    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
//    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession.logger != nil"];

    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession.status == %d", STMSessionRunning];

    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL{
                              if (!self.persister) {
                                  self.persister = [manager.currentSession persistenceDelegate];
                              }
                              self.waitForSession = NO;
                              return YES;
                          }];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut
                                 handler:nil];
    
}

- (void)tearDown {
    
    NSDate *startedAt = [NSDate date];
    NSUInteger count = 0;
    
    for (NSString *entityName in [self.persister concreteEntities]) {
        if ([self.persister storageForEntityName:entityName] == STMStorageTypeFMDB) {
            count += [self destroyOwnData:entityName];
        }
    }
    
    if (count) {
        NSLog(@"tearDown finished in %lu ms", @(-[startedAt timeIntervalSinceNow]*1000).integerValue);
    }
    
}

- (STMFakePersisting *)fakePersistingWithOptions:(STMFakePersistingOptions)options {
    
    NSString *modelName = [STMCoreAuthController.authController dataModelName];
    
    self.fakePersiser = [STMFakePersisting fakePersistingWithModelName:modelName options:options];
    self.persister = self.fakePersiser;
    return self.fakePersiser;
}

- (STMFakePersisting *)inMemoryPersisting {
    return [self fakePersistingWithOptions:@{STMFakePersistingOptionInMemoryDB}];
}

- (NSArray *)sampleDataOf:(NSString *)entityName count:(NSUInteger)count {
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    
    NSString *now = [STMFunctions stringFromNow];
    NSString *source = NSStringFromClass(self.class);
    
    for (NSUInteger i = 1; count >= i; i++) {
        
        NSString *name = [NSString stringWithFormat:@"%@ at %@ - %@", entityName, now, @(i)];
        
        [result addObject:@{
                            @"ownerXid": self.ownerXid,
                            @"name": name,
                            @"text": name,
                            @"type": @"debug",
                            @"source": source
                            }];
    }
    
    return result.copy;
    
}

- (NSUInteger)destroyOwnData:(NSString *)entityName {
    
    // Paged destroy is 10 times faster with 100K items to destroy
    NSUInteger pageSize = 10000;
    NSPredicate *cleanupPredicate = self.cleanupPredicate;;
    NSDictionary *cleanupOptions = @{
                                     STMPersistingOptionRecordstatuses:@NO,
                                     STMPersistingOptionPageSize:@(pageSize)
                                     };
    NSError *error;
    
    NSUInteger result = [self.persister destroyAllSync:entityName predicate:cleanupPredicate options:cleanupOptions error:&error];

    XCTAssertNil(error);
    
    if (result) {
        NSLog(@"destroyOwnData: %@ of %@", @(result), entityName);
        if (result >= pageSize) {
            return result + [self destroyOwnData:entityName];
        }
    }
    
    return result;
}

@end
