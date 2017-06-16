//
//  STMFmdb+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb.h"
#import "FMDB.h"
#import "STMPredicateToSQL.h"
#import "STMOperationQueue.h"

@interface STMFmdb()

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, strong) FMDatabasePool *pool;

@property (nonatomic, strong) FMDatabase *database;
@property (nonatomic, strong) NSMutableArray<FMDatabase*> *poolDatabases;
@property (nonatomic, strong) STMOperationQueue* operationQueue;
@property (nonatomic, strong) STMOperationQueue* operationPoolQueue;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@property (nonatomic, strong) NSDictionary *columnsByTable;
@property (nonatomic, strong) NSArray *builtInAttributes;
@property (nonatomic, strong) NSArray *ignoredAttributes;

@property (nonatomic, strong) STMPredicateToSQL *predicateToSQL;
@property (nonatomic, weak) id <STMModelling> modellingDelegate;
@property (nonatomic, strong) NSString *dbPath;


@end

