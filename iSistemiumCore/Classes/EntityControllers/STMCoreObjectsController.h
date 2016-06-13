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

+ (void)initObjectsCacheWithCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)checkObjectsForFlushing;

+ (void)processingOfDataArray:(NSArray *)array
               withEntityName:(NSString *)entityName
                  andRoleName:(NSString *)roleName
        withCompletionHandler:(void (^)(BOOL success))completionHandler;

//+ (void)processingOfDataArray:(NSArray *)array roleName:(NSString *)roleName withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)insertObjectsFromArray:(NSArray *)array
                withEntityName:(NSString *)entityName
         withCompletionHandler:(void (^)(BOOL success))completionHandler;

//+ (void)insertObjectsFromArray:(NSArray *)array withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)insertObjectFromDictionary:(NSDictionary *)dictionary
                    withEntityName:(NSString *)entityName
             withCompletionHandler:(void (^)(BOOL success))completionHandler;

//+ (void)insertObjectFromDictionary:(NSDictionary *)dictionary withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (void)setRelationshipsFromArray:(NSArray *)array withCompletionHandler:(void (^)(BOOL success))completionHandler;
+ (void)setRelationshipFromDictionary:(NSDictionary *)dictionary withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (NSArray <NSString *> *)localDataModelEntityNames;
+ (NSArray *)coreEntityKeys;
+ (NSArray *)coreEntityRelationships;
+ (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName;
+ (NSDictionary *)ownObjectRelationshipsForEntityName:(NSString *)entityName;
+ (NSDictionary *)singleRelationshipsForEntityName:(NSString *)entityName;

+ (NSDictionary *)dictionaryForObject:(NSManagedObject *)object;
+ (NSArray *)jsonForObjectsWithParameters:(NSDictionary *)parameters error:(NSError **)error;

//+ (void)syncObject:(NSDictionary *)objectDictionary;

+ (void)removeObject:(NSManagedObject *)object;
+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(NSManagedObject *)object;
+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(NSManagedObject *)object withComment:(NSString *)commentText;

+ (void)dataLoadingFinished;

+ (NSManagedObject *)newObjectForEntityName:(NSString *)entityName isFantom:(BOOL)isFantom;

+ (NSManagedObject *)objectForXid:(NSData *)xidData;
+ (NSManagedObject *)objectForXid:(NSData *)xidData entityName:(NSString *)entityName;

+ (NSArray *)objectsForEntityName:(NSString *)entityName;

+ (NSArray *)objectsForEntityName:(NSString *)entityName
                          orderBy:(NSString *)orderBy
                        ascending:(BOOL)ascending
                       fetchLimit:(NSUInteger)fetchLimit
                      withFantoms:(BOOL)withFantoms
           inManagedObjectContext:(NSManagedObjectContext *)context
                            error:(NSError **)error;

+ (BOOL)subscribeViewController:(UIViewController <STMEntitiesSubscribable> *)vc toEntities:(NSArray *)entities error:(NSError **)error;
+ (NSArray *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error;
+ (NSArray *)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error;
+ (NSArray *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error;
+ (NSArray *)arrayForJSWithObjects:(NSArray <STMDatum *> *)objects;

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object;
+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object withNulls:(BOOL)withNulls;

//+ (void)requestObjectWithParameters:(NSDictionary *)parameters;
+ (void)didFinishResolveFantom:(NSDictionary *)fantomDic successfully:(BOOL)successfully;
+ (void)stopDefantomizing;


@end
