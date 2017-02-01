//
//  STMCoreObjectsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

#import <CoreData/CoreData.h>
#import <WebKit/WebKit.h>

@import PromiseKit;


@interface STMCoreObjectsController : STMCoreController

+ (STMCoreObjectsController *)sharedController;

+ (void)checkObjectsForFlushing;

+ (void)processingOfDataArray:(NSArray *)array
               withEntityName:(NSString *)entityName
                  andRoleName:(NSString *)roleName
        withCompletionHandler:(void (^)(BOOL success))completionHandler;


+ (void)setObjectData:(NSDictionary *)objectData
             toObject:(STMDatum *)object;

+ (void)setRelationshipsFromArray:(NSArray *)array
            withCompletionHandler:(void (^)(BOOL success))completionHandler;

+ (BOOL)setRelationshipFromDictionary:(NSDictionary *)dictionary;

+ (NSArray <NSString *> *)localDataModelEntityNames;
+ (NSArray *)coreEntityKeys;

+ (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName;
+ (NSDictionary *)ownObjectRelationshipsForEntityName:(NSString *)entityName;
+ (NSDictionary *)toManyRelationshipsForEntityName:(NSString *)entityName;

+ (NSArray *)jsonForObjectsWithParameters:(NSDictionary *)parameters
                                    error:(NSError **)error;

+ (void)dataLoadingFinished;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName
                            isFantom:(BOOL)isFantom;

+ (STMDatum *)objectForXid:(NSData *)xidData;
+ (STMDatum *)objectForXid:(NSData *)xidData
                entityName:(NSString *)entityName;

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object;

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object
                                  withNulls:(BOOL)withNulls;

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object
                                  withNulls:(BOOL)withNulls
                             withBinaryData:(BOOL)withBinaryData;

+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage;

+ (STMDatum *)objectFindOrCreateForEntityName:(NSString *)entityName
                                       andXid:(NSData *)xidData;

+ (STMDatum *)objectFindOrCreateForEntityName:(NSString *)entityName
                                 andXidString:(NSString *)xid;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName;

+ (void)logTotalNumberOfObjectsInStorages;

@end
