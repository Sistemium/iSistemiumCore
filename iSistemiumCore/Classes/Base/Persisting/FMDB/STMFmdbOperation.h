//
// Created by Alexander Levin on 13/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Transactions.h"


@interface STMFmdbOperation : STMOperation

- (instancetype)initWithReadOnly:(BOOL)readOnly stmFMDB:(STMFmdb *)stmFMDB;
- (void)waitUntilTransactionIsReady;

@property (nonatomic, strong) STMFmdbTransaction *transaction;
@property (nonatomic, weak) STMFmdb *stmFMDB;
@property (nonatomic, strong) FMDatabase *database;
@property BOOL readOnly;
@property BOOL success;
@property dispatch_semaphore_t sem;

@end