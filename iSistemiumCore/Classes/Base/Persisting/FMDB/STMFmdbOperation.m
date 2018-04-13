//
// Created by Alexander Levin on 13/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMFmdbOperation.h"
#import "STMFunctions.h"

@implementation STMFmdbOperation

- (instancetype)initWithReadOnly:(BOOL)readOnly stmFMDB:(STMFmdb *)stmFMDB {

    self.readOnly = readOnly;

    self.stmFMDB = stmFMDB;

    self.sem = dispatch_semaphore_create(0);

    return self;

}

- (void)main {

    if (self.readOnly) {

        self.database = [STMFunctions popArray:self.stmFMDB.poolDatabases];


    } else {

        self.database = self.stmFMDB.database;

        [self.database beginTransaction];

    }

    self.transaction = [[STMFmdbTransaction alloc] initWithFMDatabase:self.database stmFMDB:self.stmFMDB];

    self.transaction.operation = self;

    dispatch_semaphore_signal(self.sem);

}

- (void)finish {

    if (!self.readOnly) {

        if (self.success) {

            [self.database commit];

        } else {

            [self.database rollback];

        }

    }

    if (self.readOnly) {

        [STMFunctions pushArray:self.stmFMDB.poolDatabases object:self.database];

    }

    [super finish];

    self.transaction.operation = nil;
    self.transaction = nil;
    self.sem = nil;
    self.database = nil;

}

- (void)waitUntilTransactionIsReady {

    dispatch_semaphore_wait(self.sem, DISPATCH_TIME_FOREVER);

}

@end
