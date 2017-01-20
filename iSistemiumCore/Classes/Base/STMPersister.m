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
#import "STMRecordStatusController.h"

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

- (NSDictionary *) mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inSTMFmdb:(STMFmdb *)db{
    
    [db startTransaction];
    
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
    
    savingAttributes[@"deviceAts"] = now;
    
    if(!returnSaved){
        [db mergeInto:entityName
           dictionary:savingAttributes
                error:error];
        return nil;
    } else {
        return [db mergeIntoAndResponse:entityName
                             dictionary:savingAttributes
                                  error:error];
    }
    
}

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    if ([entityName isEqualToString:@"STMRecordStatus"]) {
        
        if (![attributes[@"isRemoved"] isEqual:[NSNull null]] ? [attributes[@"isRemoved"] boolValue]: false) {
            
            NSPredicate* predicate;
            
            if ([[STMFmdb sharedInstance] hasTable:attributes[@"name"]]){
                predicate = [NSPredicate predicateWithFormat:@"id = %@",attributes[@"objectXid"]];
            }else{
                predicate = [NSPredicate predicateWithFormat:@"xid = %@",attributes[@"objectXid"]];
            }
            
            [self destroyWithoutSave:attributes[@"name"] predicate:predicate options:@{@"createRecordStatuses":@NO} error:error];
            
        }
        
        if (![attributes[@"isTemporary"] isEqual:[NSNull null]] && [attributes[@"isTemporary"] boolValue]) return nil;
    }
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        
        return [self mergeWithoutSave:entityName
                           attributes:attributes
                              options:options
                                error:error
                            inSTMFmdb:STMFmdb.sharedInstance];
        
    } else {
        
        if (options[@"roleName"]){
            [STMCoreObjectsController setRelationshipFromDictionary:attributes withCompletionHandler:^(BOOL sucess){
                if (!sucess) {
                    [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error inserting %@", entityName]];
                }
            }];
        }else{
            [STMCoreObjectsController  insertObjectFromDictionary:attributes withEntityName:entityName withCompletionHandler:^(BOOL sucess){
                if (!sucess) {
                    [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Relationship error %@", entityName]];
                }
            }];
        }
        
        return attributes;
    }
}

- (BOOL)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSArray* objects = @[];
    
    if (!options[@"createRecordStatuses"] || [options[@"createRecordStatuses"] boolValue]){
        objects = [self findAllSync:entityName predicate:predicate options:options error:error];
    }
    
    NSString* idKey;
    
    BOOL result = YES;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        
        idKey = @"id";
        
        result = [[STMFmdb sharedInstance] destroy:entityName predicate:predicate error:error];
        
    }else{
        
        idKey = @"xid";
        
        [STMCoreObjectsController removeObjectForPredicate:predicate entityName:entityName];

    }
    
    for (NSDictionary* object in objects){
        
        NSDictionary *recordStatus = @{@"objectXid":object[idKey], @"name":[STMFunctions entityToTableName:entityName], @"isRemoved": @YES};
        
        [self mergeWithoutSave:@"STMRecordStatus" attributes:recordStatus options:nil error:error];
        
    }
    
    return result;
    
}

- (BOOL)saveWithEntityName:(NSString *)entityName{
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        return [[STMFmdb sharedInstance] commit];
    } else {
        [[self document] saveDocument:^(BOOL success){}];
        return YES;
    }
    
}


#pragma mark - STMPersistingSync

- (NSUInteger)countSync:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options
                  error:(NSError **)error {
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
#warning predicates not supported yet
        // TODO: make generic predicate to SQL method with predicate filtering
        return [[STMFmdb sharedInstance] count:entityName withPredicate:[NSPredicate predicateWithFormat:@"isFantom == 0"]];
    } else {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        return [[self document].managedObjectContext countForFetchRequest:request error:error];
    }
    
}

- (NSDictionary *)findSync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        predicate = [NSPredicate predicateWithFormat:@"isFantom = 0 and id == %@",identifier];
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
    NSUInteger offset = [options[@"startPage"] integerValue];
    if (offset) {
        offset -= 1;
        offset *= pageSize;
    }
    NSString *orderBy = options[@"sortBy"];
    
    BOOL asc = options[@"ASC"] ? [options[@"ASC"] boolValue] : YES;
    
    // TODO: maybe could be simplified
    NSMutableArray *predicates = [[NSMutableArray alloc] init];
    
    [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom = %d", options[@"fantoms"] ? 1 : 0]];
    
    if (predicate) {
        [predicates addObject:predicate];
    }
    
    NSCompoundPredicate *predicateWithFantoms = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    if (!orderBy) orderBy = @"id";
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){

        return [[STMFmdb sharedInstance] getDataWithEntityName:entityName
                                                 withPredicate:predicateWithFantoms
                                                       orderBy:orderBy
                                                    ascending:asc
                                                    fetchLimit:options[@"pageSize"] ? &pageSize : nil
                                                   fetchOffset:options[@"offset"] ? &offset : nil];

    } else {
        NSArray* objectsArray = [STMCoreObjectsController objectsForEntityName:entityName
                                                                       orderBy:orderBy
                                                                     ascending:asc
                                                                    fetchLimit:pageSize
                                                                   fetchOffset:offset
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

- (BOOL)destroySync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    if([[STMFmdb sharedInstance] hasTable:entityName]){
        predicate = [NSPredicate predicateWithFormat:@"id = %@",identifier];
    }else{
        predicate = [NSPredicate predicateWithFormat:@"xid = %@", identifier];
    }
    
    return [self destroyAllSync:entityName predicate:predicate options:options error:error];
    
}

- (BOOL)destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    [self destroyWithoutSave:entityName predicate:predicate options:options error:error];
    
    if (error){
        #warning possible danger, will rollback changes from other threads
        [[STMFmdb sharedInstance] rollback];
        return NO;
    }
    
    if ([self saveWithEntityName:entityName]){
        return YES;
    } else {
        [STMCoreObjectsController error:error withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
        return YES;
    }
    
}

#pragma mark - STMPersistingAsync

- (void)findAsync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findSync:entityName id:identifier options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self findSync:entityName id:identifier options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self findAllSync:entityName predicate:predicate options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self findAllSync:entityName predicate:predicate options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler{
    
    __block NSDictionary* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeSync:entityName attributes:attributes options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self mergeSync:entityName attributes:attributes options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)mergeManyAsync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler{
    
    __block NSArray* result;
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,result,error);
        });
    } else {
        result = [self mergeManySync:entityName attributeArray:attributeArray options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,result,error);
    }
}

- (void)destroyAsync:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options completionHandler:(void (^)(BOOL success, NSError *error))completionHandler{
    __block BOOL success = YES;
    __block NSError* error = nil;
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            success = [self destroySync:entityName id:identifier options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,error);
        });
    }else{
        success = [self destroySync:entityName id:identifier options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,error);
    }
}

- (void)destroyAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options
   completionHandler:(void (^)(BOOL success, NSError *error))completionHandler{
    
    __block BOOL success = YES;
    __block NSError* error = nil;
    
    if ([[STMFmdb sharedInstance] hasTable:entityName]){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            success = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
            if(error){
                success = NO;
            }
            completionHandler(success,error);
        });
    }else{
        success = [self destroyAllSync:entityName predicate:predicate options:options error:&error];
        if(error){
            success = NO;
        }
        completionHandler(success,error);
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

- (AnyPromise *)destroy:(NSString *)entityName id:(NSString *)identifier options:(NSDictionary *)options{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self destroyAsync:entityName id:identifier options:options completionHandler:^(BOOL success, NSError *error){
            if (success){
                resolve([NSNumber numberWithBool:success]);
            }else{
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)destroyAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options{

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [self destroyAllAsync:entityName predicate:predicate options:options completionHandler:^(BOOL success, NSError *error){
            if (success){
                resolve([NSNumber numberWithBool:success]);
            }else{
                resolve(error);
            }
        }];
    }];
    
}

@end
