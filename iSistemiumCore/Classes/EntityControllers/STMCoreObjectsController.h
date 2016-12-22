//
//  STMCoreObjectsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

#import <CoreData/CoreData.h>
#import <Crashlytics/Crashlytics.h>
#import <WebKit/WebKit.h>

#import "STMEntitiesSubscribable.h"


@interface STMCoreObjectsController : STMCoreController

+ (STMCoreObjectsController *)sharedController;

+ (void)checkObjectsForFlushing;

+ (void)processingOfDataArray:(NSArray *)array
               withEntityName:(NSString *)entityName
                  andRoleName:(NSString *)roleName
        withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)insertObjectsFromArray:(NSArray *)array
                withEntityName:(NSString *)entityName
         withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)insertObjectFromDictionary:(NSDictionary *)dictionary
                    withEntityName:(NSString *)entityName
             withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)setObjectData:(NSDictionary *)objectData
             toObject:(STMDatum *)object;

+ (void)setRelationshipsFromArray:(NSArray *)array
            withCompletionHandler:(void (^)(BOOL success))completionHandler;
+ (void)setRelationshipFromDictionary:(NSDictionary *)dictionary
                withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (NSArray <NSString *> *)localDataModelEntityNames;
+ (NSArray *)coreEntityKeys;
+ (NSArray *)coreEntityRelationships;
+ (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName;
+ (NSDictionary *)ownObjectRelationshipsForEntityName:(NSString *)entityName;
+ (NSDictionary *)toOneRelationshipsForEntityName:(NSString *)entityName;
+ (NSDictionary *)toManyRelationshipsForEntityName:(NSString *)entityName;

+ (NSArray *)jsonForObjectsWithParameters:(NSDictionary *)parameters
                                    error:(NSError **)error;

+ (void)removeObject:(STMDatum *)object;
+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(STMDatum *)object;
+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(STMDatum *)object
                                           withComment:(NSString *)commentText;

+ (void)dataLoadingFinished;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName
                            isFantom:(BOOL)isFantom;

+ (STMDatum *)objectForXid:(NSData *)xidData;
+ (STMDatum *)objectForXid:(NSData *)xidData
                entityName:(NSString *)entityName;

+ (NSArray *)objectsForEntityName:(NSString *)entityName;

+ (NSArray *)objectsForEntityName:(NSString *)entityName
                          orderBy:(NSString *)orderBy
                        ascending:(BOOL)ascending
                       fetchLimit:(NSUInteger)fetchLimit
                      withFantoms:(BOOL)withFantoms
           inManagedObjectContext:(NSManagedObjectContext *)context
                            error:(NSError **)error;

+ (BOOL)subscribeViewController:(UIViewController <STMEntitiesSubscribable> *)vc
                     toEntities:(NSArray *)entities
                          error:(NSError **)error;
+ (NSArray *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage
                                      error:(NSError **)error;
+ (NSArray *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage
                                              error:(NSError **)error;

+ (void)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage
                 withCompletionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler;

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object;
+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object
                                  withNulls:(BOOL)withNulls;
+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object
                                  withNulls:(BOOL)withNulls
                             withBinaryData:(BOOL)withBinaryData;

+ (void)resolveFantoms;
+ (void)didFinishResolveFantom:(NSDictionary *)fantomDic
                  successfully:(BOOL)successfully;
+ (void)stopDefantomizing;
+ (BOOL)isDefantomizingProcessRunning;


@end
