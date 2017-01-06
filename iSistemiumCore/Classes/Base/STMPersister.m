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
//@property (nonatomic, strong) STMDocument *document;

@end

@implementation STMPersister

@synthesize document;

+ (instancetype)initWithDocument:(STMDocument *)stmdocument{
    
    STMPersister* persister = [[STMPersister alloc] init];
    
    persister.document = stmdocument;
    
    return persister;
}

#pragma mark - STMPersistingSync

- (NSDictionary *)findSyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error{
    return nil;
}

- (NSArray *)findAllSyncWithEntityName:(NSString *)entityName withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options withError:(NSError *)error{
    return nil;
}

- (NSDictionary *)mergeSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options withError:(NSError *)error{
    return nil;
}

- (NSArray *)mergeManySyncWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options withError:(NSError *)error{
    return nil;
}

- (bool *)destroySyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error{
    return nil;
}

- (NSDictionary *)createSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options WithError:(NSError *)error{
    return nil;
}

- (NSDictionary *)updateSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options WithError:(NSError *)error{
    return nil;
}

#pragma mark - STMPersistingAsync

- (NSArray *)updateAllSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options WithError:(NSError *)error{
    return nil;
}

- (void)findAsyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler{
}

- (void)findAllAsyncWithEntityName:(NSString *)entityName withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler{
}

- (void)mergeAsyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler{
}

- (void)mergeManyAsyncWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler{
}

- (void)destroyAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(bool *))completionHandler{
}

- (void)createAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler{
}

- (void)updateAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler{
}

- (void)updateAllAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler{
}

#pragma mark - STMPersistingPromised

- (AnyPromise *)findPromisedWithEntityName:(NSString *)entityName qithId:(NSDictionary *)identifier qithOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)findPromisedAllWithEntityName:(NSString *)entityName qithPredicate:(NSPredicate *)predicate qithOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)mergePromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)mergeManyPromisedWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)destroyPromisedWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)createPromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)updatePromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options{
    return nil;
}

- (AnyPromise *)updateAllPromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options{
    return nil;
}

@end
