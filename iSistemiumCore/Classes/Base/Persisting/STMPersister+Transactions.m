//
//  STMPersister+Transactions.m
//  iSisSales
//
//  Created by Alexander Levin on 18/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Transactions.h"
#import "STMPersister+Private.h"
#import "STMFmdb+Transactions.h"
#import "STMFunctions.h"
#import "STMPersister+CoreData.h"

@interface STMPersisterTransaction : STMFmdbTransaction

@property (nonatomic,weak) STMPersister *persister;

+ (instancetype)persistingTransactionWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB persister:(STMPersister *)persister;
- (instancetype)initWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB persister:(STMPersister *)persister;

@end

@interface STMPersisterTransaction()

@property (nonatomic) BOOL needSaveDocument;

@end

@implementation STMPersisterTransaction

+ (instancetype)persistingTransactionWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB persister:(STMPersister *)persister {
    return [[self alloc] initWithFMDatabase:database stmFMDB:stmFMDB persister:persister];
}

- (instancetype)initWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB persister:(STMPersister *)persister {
    self = [self initWithFMDatabase:database stmFMDB:stmFMDB];
    self.persister = persister;
    return self;
}


#pragma mark - PersistingTransaction protocol

- (id <STMModelling>)modellingDelegate {
    return self.persister;
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger pageSize = [options[STMPersistingOptionPageSize] integerValue];
    NSUInteger offset = [options[@"startPage"] integerValue];
    
    if (offset) {
        offset -= 1;
        offset *= pageSize;
    }
    
    NSString *orderBy = options[STMPersistingOptionOrder];
    
    BOOL asc = options[STMPersistingOptionOrderDirection] ? [[options[STMPersistingOptionOrderDirection] lowercaseString] isEqualToString:@"asc"] : YES;
    
    
    if (!orderBy) orderBy = @"id";
    
    predicate = [self.persister predicate:predicate withOptions:options];
    
    switch ([self.persister storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            
            return [super findAllSync:entityName predicate:predicate orderBy:orderBy ascending:asc fetchLimit:pageSize fetchOffset:offset];
            
        case STMStorageTypeCoreData: {
            NSArray* objectsArray = [self.persister objectsForEntityName:entityName
                                                                 orderBy:orderBy
                                                               ascending:asc
                                                              fetchLimit:pageSize
                                                             fetchOffset:offset
                                                             withFantoms:YES
                                                               predicate:predicate
                                                              resultType:NSManagedObjectResultType
                                                  inManagedObjectContext:self.persister.document.managedObjectContext
                                                                   error:error];
            
            return [self.persister arrayForJSWithObjects:objectsArray];
            
        }
        default:
            [self.persister wrongEntityName:entityName error:error];
            return nil;
    }
    
}


- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    switch ([self.persister storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB: {
            return [super mergeWithoutSave:entityName attributes:attributes options:options error:error];
        }
        case STMStorageTypeCoreData: {
            self.needSaveDocument = YES;
            options = [self fixMergeOptions:options entityName:entityName];
            return [self.persister mergeWithoutSave:entityName attributes:attributes options:options error:error inManagedObjectContext:self.persister.document.managedObjectContext];
            break;
        }
        default:{
            [self.persister wrongEntityName:entityName error:error];
            return nil;
        }
    }
    
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    NSArray* objects = @[];
    
    // FIXME: expendable fetch on one object destroy
    if (!options[STMPersistingOptionRecordstatuses] || [options[STMPersistingOptionRecordstatuses] boolValue]){
        objects = [self findAllSync:entityName predicate:predicate options:options error:error];
    }
    
    NSUInteger count = 0;

    switch ([self.persister storageForEntityName:entityName options:options]) {
            
        case STMStorageTypeFMDB:
            count = [super destroyWithoutSave:entityName predicate:predicate options:options error:error];
            break;
        case STMStorageTypeCoreData:
            self.needSaveDocument = YES;
            count = [self.persister removeObjectForPredicate:predicate entityName:entityName];
            break;
        default:
            [self.persister wrongEntityName:entityName error:error];
            return 0;
    }
    
    for (NSDictionary *object in objects){
        
        NSDictionary *recordStatus = @{
                                       @"objectXid":object[STMPersistingKeyPrimary],
                                       @"name":[STMFunctions removePrefixFromEntityName:entityName],
                                       @"isRemoved": @YES,
                                       };
        
        [self mergeWithoutSave:@"STMRecordStatus" attributes:recordStatus options:@{STMPersistingOptionRecordstatuses:@NO} error:error];
        
    }
    
    return count;
    
}


- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    switch ([self.persister storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB: {
            return [super updateWithoutSave:entityName attributes:attributes options:options error:error];
        }
        case STMStorageTypeCoreData: {
            self.needSaveDocument = YES;
            options = [self fixMergeOptions:options entityName:entityName];
            return [self.persister update:entityName attributes:attributes options:options error:error inManagedObjectContext:self.persister.document.managedObjectContext];
            break;
        }
        default:{
            [self.persister wrongEntityName:entityName error:error];
            return 0;
        }
    }
    
}


#pragma mark - Private helpers

- (NSDictionary *)fixMergeOptions:(NSDictionary *)options
                       entityName:(NSString *)entityName{
    
    if ([self.persister storageForEntityName:entityName options:options] == STMStorageTypeCoreData && options[STMPersistingOptionLts]) {
        NSDate *lts = [STMFunctions dateFromString:options[STMPersistingOptionLts]];
        // Add 1ms because there are microseconds in deviceTs
        options = [STMFunctions setValue:[lts dateByAddingTimeInterval:1.0/1000.0]
                                  forKey:STMPersistingOptionLts
                            inDictionary:options];
    }
    
    return options;
    
}

@end


#pragma mark - Category methods

@implementation STMPersister (Transactions)


- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block {
 
    [self.fmdb.queue inDeferredTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        STMPersisterTransaction *transaction = [STMPersisterTransaction persistingTransactionWithFMDatabase:db stmFMDB:self.fmdb persister:self];
        
        BOOL result = block(transaction);
        
        if (!result) *rollback = YES;
        
        if (transaction.needSaveDocument) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.document saveDocument:^(BOOL success) {}];
            });
        }
        
    }];
    
}


- (STMStorageType)storageForEntityName:(NSString *)entityName options:(NSDictionary *)options {
    
    STMStorageType storeTo = [self storageForEntityName:entityName];
    
    if (options[STMPersistingOptionForceStorage]) {
        storeTo = [options[STMPersistingOptionForceStorage] integerValue];
    }
    
    return storeTo;
}


- (NSPredicate *)predicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options {
    
    NSMutableArray *predicates = NSMutableArray.array;
    
    BOOL isFantom = [options[STMPersistingOptionFantoms] boolValue];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom = %@", @(isFantom)]];
    
    if (predicate) {
        [predicates addObject:predicate];
    }
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
}


- (NSPredicate *)primaryKeyPredicateEntityName:(NSString *)entityName values:(NSArray <NSString *> *)values options:(NSDictionary *)options {
    
    if ([self storageForEntityName:entityName options:options] != STMStorageTypeCoreData) {
        return [super primaryKeyPredicateEntityName:entityName values:values];
    }
    
    NSArray *xids = [STMFunctions mapArray:values withBlock:^id (id value) {
        return [STMFunctions xidDataFromXidString:value];
    }];
    
    return [NSPredicate predicateWithFormat:@"xid IN %@", xids];
    
}

@end
