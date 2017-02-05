//
//  STMSyncerHelper+Defantomizing.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Defantomizing.h"
#import "STMConstants.h"
#import "STMEntityController.h"
#import "STMCoreObjectsController.h"

#import <objc/runtime.h>


static void *failToResolveFantomsArrayVar;


@implementation STMSyncerHelper (Defantomizing)


#pragma mark - variables

- (NSMutableArray *)failToResolveFantomsArray {
    
    NSMutableArray *result = objc_getAssociatedObject(self, &failToResolveFantomsArrayVar);
    
    if (!result) {
        
        result = @[].mutableCopy;
        objc_setAssociatedObject(self, &failToResolveFantomsArrayVar, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    
    return result;
    
}


#pragma mark - defantomizing

- (void)findFantomsWithCompletionHandler:(void (^)(NSArray <NSDictionary *> *fantomsArray))completionHandler {
    
    NSMutableArray <NSDictionary *> *fantomsArray = @[].mutableCopy;
    
    NSArray *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
    for (NSString *entityName in entityNamesWithResolveFantoms) {
        
        STMEntity *entity = [STMEntityController stcEntities][entityName];
        
        if (!entity.url) {
            
            NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            continue;
            
        }
        
        NSError *error = nil;
        NSArray *results = [self.persistenceDelegate findAllSync:entityName
                                                       predicate:nil
                                                         options:@{STMPersistingOptionFantoms:@YES}
                                                           error:&error];
        
        NSArray *failToResolveFantomsIds = [self.failToResolveFantomsArray valueForKeyPath:@"id"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (id IN %@)", failToResolveFantomsIds];
        
        results = [results filteredArrayUsingPredicate:predicate];
        
        if (results.count > 0) {
            
            NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);
            
            for (NSDictionary *fantomObject in results) {
                
                if (!fantomObject[@"id"]) {
                    
                    NSLog(@"fantomObject have no id: %@", fantomObject);
                    continue;
                    
                }
                
                NSDictionary *fantomDic = @{@"entityName":entityName, @"id":fantomObject[@"id"]};
                [fantomsArray addObject:fantomDic];
                
            }
            
        } else {
            //            NSLog(@"have no fantoms for %@", entityName);
        }
        
    }
    
    if (fantomsArray.count > 0) {
        
        NSLog(@"DEFANTOMIZING_START");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_START
                                                                object:self
                                                              userInfo:@{@"fantomsCount": @(fantomsArray.count)}];
            
        });
        
    }
    
    if (completionHandler) {
        completionHandler(fantomsArray.count ? fantomsArray : nil);
    }
    
}

- (void)defantomizeErrorWithObject:(NSDictionary *)fantomDic deleteObject:(BOOL)deleteObject {
    
    if (deleteObject) {
        
        NSString *entityName = fantomDic[@"entityName"];
        NSString *objId = fantomDic[@"id"];
        
        NSLog(@"delete fantom %@ %@", entityName, objId);
        
        [self.persistenceDelegate destroySync:entityName
                                   identifier:objId
                                      options:nil
                                        error:nil];
        
    } else {
        
        @synchronized (self) {
            [self.failToResolveFantomsArray addObject:fantomDic];
        }
        
    }
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_FINISH
                                                            object:self
                                                          userInfo:nil];
        
    });
    
    // do not nil object used in syncronized()
    [self.failToResolveFantomsArray removeAllObjects];
    
}

@end
