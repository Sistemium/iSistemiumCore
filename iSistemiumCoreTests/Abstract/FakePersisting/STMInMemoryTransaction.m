//
//  STMInMemoryTransaction.m
//  iSisSales
//
//  Created by Alexander Levin on 20/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMInMemoryTransaction.h"

@interface STMInMemoryTransaction ()

@property (nonatomic,weak) STMFakePersisting *persister;

@end

@implementation STMInMemoryTransaction

+ (instancetype)inMemoryTransactionWithInMemoryPersister:(STMFakePersisting *)persister {
    return [[self alloc] initWithInMemoryPersister:persister];
}

- (instancetype)initWithInMemoryPersister:(STMFakePersisting *)persister {
    self.persister = persister;
    return self;
}


-(id)modellingDelegate {
    return self.persister;
}

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    return nil;
}

- (NSUInteger)count:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    return 0;
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    return 0;
}

- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    return nil;
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    return nil;
}

@end
