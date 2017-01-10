//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersister.h"

#import "STMConstants.h"
#import "STMCoreAuthController.h"

#import "STMFmdb.h"
#import "STMCoreObjectsController.h"

@import PromiseKit;

@interface STMPersister()

@property (nonatomic, weak) id <STMSession> session;
@end


@implementation STMPersister

+ (instancetype)initWithSession:(id <STMSession>)session {
    
    STMPersister *persister = [[STMPersister alloc] init];
    
    persister.session = session;
    
    NSString *dataModelName = [session.startSettings valueForKey:@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMDocument *document = [STMDocument documentWithUID:session.uid
                                                  iSisDB:session.iSisDB
                                           dataModelName:dataModelName];

    persister.document = document;
    
    return persister;
    
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}

#pragma mark - observers

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self.session];

    [nc addObserver:self
           selector:@selector(documentReady:)
               name:NOTIFICATION_DOCUMENT_READY
             object:nil];
    
    [nc addObserver:self
           selector:@selector(documentNotReady:)
               name:NOTIFICATION_DOCUMENT_NOT_READY
             object:nil];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if ([notification.object conformsToProtocol:@protocol(STMSession)]) {
        
        id <STMSession>session = (id <STMSession>)notification.object;
        
        if (session == self.session) {
            
            if (session.status == STMSessionRemoving) {
                
                [self removeObservers];
                self.session = nil;
                
            }
            
        }
        
    }

}

- (void)documentReady:(NSNotification *)notification {
    
    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:YES];
        // here we can remove document observers
        
    }

}

- (void)documentNotReady:(NSNotification *)notification {

    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:NO];
        // here we can remove document observers

    }

}

#pragma mark - STMPersistingSync

- (NSDictionary *)findSync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options error:(NSError *)error{
    NSPredicate* predicate;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        predicate = [NSPredicate predicateWithFormat:@"id == %@",identifier];
    }else{
        predicate = [NSPredicate predicateWithFormat:@"xid == %@",identifier];
    }
    return [self findAllSync:entityName predicate:predicate options:options error:error][0];
}

- (NSArray *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError *)error{
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger startPage = [options[@"startPage"] integerValue] - 1;
    NSString *orderBy = options[@"sortBy"];
    if (!orderBy) orderBy = @"id";
    if (!startPage) startPage = 0;
    if (!pageSize) pageSize = 0;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        return [[STMFmdb sharedInstance] getDataWithEntityName:entityName withPredicate:predicate];
    }else{
        NSArray* objectsArray = [STMCoreObjectsController objectsForEntityName:entityName
                                                                       orderBy:orderBy
                                                                     ascending:YES
                                                                    fetchLimit:pageSize
                                                                   fetchOffset:(pageSize * startPage)
                                                                   withFantoms:NO
                                                                     predicate:predicate
                                                                    resultType:NSDictionaryResultType
                                                        inManagedObjectContext:[self document].managedObjectContext
                                                                         error:&error];
        
        return [STMCoreObjectsController arrayForJSWithObjectsDics:objectsArray entityName:entityName];
    }
}

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *)error{
    __block NSDictionary* result = nil;
    __block NSError* blockError = nil;
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        result = [[STMFmdb sharedInstance] insertWithTablename:entityName dictionary:attributes];
        return result;
    }else{
        [STMCoreObjectsController  insertObjectFromDictionary:attributes withEntityName:entityName withCompletionHandler:^(BOOL sucess){
            blockError = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey: @"insert error"}];
            result = attributes;
        }];
        error = blockError;
        return result;
    }
}

- (void)saveWithEntityName:(NSString *)entityName error:(NSError *)error{
    __block NSError* blockError = nil;
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        [[STMFmdb sharedInstance] commit];
    }else{
        [[self document] saveDocument:^(BOOL success){
            if (!success){
                blockError = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                 code:0
                                             userInfo:@{NSLocalizedDescriptionKey: @"document save failed"}];
                
            }
        }];
    }
    error = blockError;

}

- (NSDictionary *)mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *)error{
    NSDictionary* result = [self mergeWithoutSave:entityName attributes:attributes options:options error:error];
    if (!error){
        [self saveWithEntityName:entityName error:error];
        if (!error){
            return result;
        }
    }
    return nil;
}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError *)error{
    for (NSDictionary* dictionary in attributeArray){
        [self mergeWithoutSave:entityName attributes:dictionary options:options error:error];
        if (error){
            return nil;
        }
    }
    [self saveWithEntityName:entityName error:error];
    if (!error){
        return attributeArray;
    }
    return nil;
}

#pragma mark - STMPersistingAsync

- (void)findAsync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findSync:entityName id:identifier options:options error:error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self findSync:entityName id:identifier options:options error:error];
        completionHandler(success,result,error);
    }
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findAllSync:entityName predicate:predicate options:options error:error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self findAllSync:entityName predicate:predicate options:options error:error];
        completionHandler(success,result,error);
    }
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeSync:entityName attributes:attributes options:options error:error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self mergeSync:entityName attributes:attributes options:options error:error];
        completionHandler(success,result,error);
    }
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:error];
        completionHandler(success,result,error);
    }
}


#pragma mark - STMPersistingPromised

- (AnyPromise *)find:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self findAsync:entityName id:identifier options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)findAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self findAllAsync:entityName predicate:predicate options:options completionHandler:^(BOOL success, NSArray *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)merge:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self mergeAsync:entityName attributes:attributes options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)mergeMany:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self mergeManyAsync:entityName attributeArray:attributeArray options:options completionHandler:^(BOOL success, NSArray *result, NSError *error){
            if (success){
                resolve(result);
            }else{
                resolve(error);
            }
        }];
    }];
}

@end
