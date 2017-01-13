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

#pragma mark - Private methods

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        
        [[STMFmdb sharedInstance] startTransaction];
        
        NSString *now = [STMFunctions stringFromNow];
        NSMutableDictionary *savingAttributes = attributes.mutableCopy;
        BOOL returnSaved = !([options[@"returnSaved"]  isEqual: @NO] || options[@"lts"]);
        
        if (options[@"lts"]) {
            [savingAttributes setValue:options[@"lts"] forKey:@"lts"];
            [savingAttributes removeObjectForKey:@"deviceTs"];
        } else {
            [savingAttributes setValue:now forKey:@"deviceTs"];
            [savingAttributes removeObjectForKey:@"lts"];
        }
        
        [savingAttributes setValue:now forKey:@"deviceAts"];
        
        if(!returnSaved){
            [[STMFmdb sharedInstance] mergeInto:entityName dictionary:savingAttributes error:error];
            return nil;
        }else{
            return [[STMFmdb sharedInstance] mergeIntoAndResponse:entityName dictionary:savingAttributes error:error];
        }
        
    } else {
        
        [STMCoreObjectsController  insertObjectFromDictionary:attributes withEntityName:entityName withCompletionHandler:^(BOOL sucess){
            if (!sucess) {
                [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error inserting %@", entityName]];
            }
        }];
        
        return attributes;
    }
}

- (BOOL)saveWithEntityName:(NSString *)entityName{
    
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        return [[STMFmdb sharedInstance] commit];
    } else {
        [[self document] saveDocument:^(BOOL success){}];
        return YES;
    }
    
}


#pragma mark - STMPersistingSync

- (NSDictionary *)findSync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        predicate = [NSPredicate predicateWithFormat:@"id == %@",identifier];
    }else{
        predicate = [NSPredicate predicateWithFormat:@"xid == %@",identifier];
    }
    
    NSArray *results = [self findAllSync:entityName predicate:predicate options:options error:error];
    
    if (results.count) {
        return results.firstObject;
    } else {
        return nil;
    }
    
}

- (NSArray *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger startPage = [options[@"startPage"] integerValue] - 1;
    NSString *orderBy = options[@"sortBy"];
    
    if (!orderBy) orderBy = @"id";
    if (!startPage) startPage = 0;
    if (!pageSize) pageSize = 0;
    
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        return [[STMFmdb sharedInstance] getDataWithEntityName:entityName withPredicate:predicate];
    } else {
        NSArray* objectsArray = [STMCoreObjectsController objectsForEntityName:entityName
                                                                       orderBy:orderBy
                                                                     ascending:YES
                                                                    fetchLimit:pageSize
                                                                   fetchOffset:(pageSize * startPage)
                                                                   withFantoms:NO
                                                                     predicate:predicate
                                                                    resultType:NSDictionaryResultType
                                                        inManagedObjectContext:[self document].managedObjectContext
                                                                         error:error];
        
        return [STMCoreObjectsController arrayForJSWithObjectsDics:objectsArray entityName:entityName];
    }
}

- (NSDictionary *)mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    NSDictionary* result = [self mergeWithoutSave:entityName attributes:attributes options:options error:error];
    
    if (*error){
        [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error merging %@", entityName]];
        return nil;
    }
    
    if (![self saveWithEntityName:entityName]){
        [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
        return nil;
    }
    
    return result;

}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError **)error{
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSDictionary* dictionary in attributeArray){
        
        NSDictionary* dict = [self mergeWithoutSave:entityName attributes:dictionary options:options error:error];
        
        if (dict){
            [result addObject:dict];
        }
        
        if (*error){
            #warning possible danger, will rollback changes from other threads
            [[STMFmdb sharedInstance] rollback];
            return nil;
        }
    }
    if ([self saveWithEntityName:entityName]){
        return result;
    } else {
        [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
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
            result = [self findSync:entityName id:identifier options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self findSync:entityName id:identifier options:options error:&error];
        completionHandler(success,result,error);
    }
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findAllSync:entityName predicate:predicate options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self findAllSync:entityName predicate:predicate options:options error:&error];
        completionHandler(success,result,error);
    }
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeSync:entityName attributes:attributes options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self mergeSync:entityName attributes:attributes options:options error:&error];
        completionHandler(success,result,error);
    }
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    }else{
        result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
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
