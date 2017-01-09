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


#pragma mark - STMPersistingAsync


#pragma mark - STMPersistingPromised

- (AnyPromise *)merge:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options{
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        return [[STMFmdb sharedInstance] insertWithTablename:entityName dictionary:attributes].then(^(NSDictionary *result){
            [[STMFmdb sharedInstance] commit];
        });
    }else{
        return[AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            [STMCoreObjectsController  insertObjectFromDictionary:attributes withEntityName:entityName withCompletionHandler:^(BOOL sucess){
                if (sucess){
                    resolve(attributes);
                }else{
                    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
                    
                    NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                         code:0
                                                     userInfo:@{NSLocalizedDescriptionKey: @"insert error"}];
                    
                    resolve(error);
                }
            }];
        }].then(^(NSDictionary *result){
            [[self document] saveDocument:^(BOOL success){
                if (!success){
                    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
                    
                    NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                         code:0
                                                     userInfo:@{NSLocalizedDescriptionKey: @"document save failed"}];
                    @throw error;
                }
            }];
        });
    }
}

- (AnyPromise *)mergeMany:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options{
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        return [[STMFmdb sharedInstance] insertWithTablename:entityName array:attributeArray].then(^(NSArray *result){
            [[STMFmdb sharedInstance] commit];
        });;
    }else{
        return[AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            [STMCoreObjectsController insertObjectsFromArray:attributeArray withEntityName:entityName withCompletionHandler:^(BOOL sucess){
                if (sucess){
                    resolve(attributeArray);
                }else{
                    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
                    
                    NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                         code:0
                                                     userInfo:@{NSLocalizedDescriptionKey: @"insert error"}];

                    resolve(error);
                }
            }];
        }].then(^(NSArray *result){
            [[self document] saveDocument:^(BOOL success){
                if (!success){
                    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
                    
                    NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                         code:0
                                                     userInfo:@{NSLocalizedDescriptionKey: @"document save failed"}];
                    @throw error;
                }
            }];
        });
    }
}

- (AnyPromise *)findAll:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options{
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger startPage = [options[@"startPage"] integerValue] - 1;
    NSString *orderBy = options[@"sortBy"];
    if (!orderBy) orderBy = @"id";
    
    
    
    if ([[STMFmdb sharedInstance] containstTableWithNameWithName:entityName]){
        NSLog(@"fmdb get dictionaries %@", @([NSDate timeIntervalSinceReferenceDate]));
        if (predicate){
            return [[STMFmdb sharedInstance] getDataWithEntityName:entityName withPredicate:predicate];
        }else{
            return [[STMFmdb sharedInstance] getDataWithEntityName:entityName];
        }
    } else {
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            NSError* error = nil;
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
            NSLog(@"find get dictionaries %@", @([NSDate timeIntervalSinceReferenceDate]));
            
            if (error) {
                return resolve(error);
            } else {
                resolve([STMCoreObjectsController arrayForJSWithObjectsDics:objectsArray entityName:entityName]);
            }
        }];
    }
}

@end
