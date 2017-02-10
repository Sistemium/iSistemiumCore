//
//  STMLogger+Logger.m
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMLogger+Private.h"
#import "STMFunctions.h"
#import "STMCoreObjectsController.h"

@implementation STMLogger (Logger)

#pragma mark - Category methods

+ (STMLogger *)sharedLogger {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedLogger = nil;
    
    dispatch_once(&pred, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
    
}

+ (void)requestInfo:(NSString *)xidString {
    [[self sharedLogger] requestInfo:xidString];
}

+ (void)requestObjects:(NSDictionary *)parameters {
    [[self sharedLogger] requestObjects:parameters];
}

+ (void)requestDefaults {
    [[self sharedLogger] requestDefaults];
}

- (NSString *)stringTypeForNumType:(STMLogMessageType)numType {
    
    switch (numType) {
        case STMLogMessageTypeImportant: {
            return @"important";
            break;
        }
        case STMLogMessageTypeError: {
            return @"error";
            break;
        }
        case STMLogMessageTypeWarning: {
            return @"warning";
            break;
        }
        case STMLogMessageTypeInfo: {
            return @"info";
            break;
        }
        case STMLogMessageTypeDebug: {
            return @"debug";
            break;
        }
    }
    
}


- (NSArray *)syncingTypesForSettingType:(NSString *)settingType {
    
    NSMutableArray *types = [self availableTypes].mutableCopy;
    
    if ([settingType isEqualToString:@"debug"]) {
        return types;
    } else {
        [types removeObject:@"debug"];
        
        if ([settingType isEqualToString:@"info"]) {
            return types;
        } else {
            [types removeObject:@"info"];
            
            if ([settingType isEqualToString:@"warning"]) {
                return types;
            } else {
                [types removeObject:@"warning"];
                
                if ([settingType isEqualToString:@"error"]) {
                    return types;
                } else {
                    [types removeObject:@"error"];
                    return types;
                    
                }
                
            }
            
        }
        
    }
    
    // type @"important" sync always
    
}

- (NSString *)loggerKey {
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *loggerKey = [bundleIdentifier stringByAppendingString:@".logger"];
    
    return loggerKey;
    
}

#pragma mark - STMLogger Protocol

- (void)saveLogMessageWithText:(NSString *)text
                       numType:(STMLogMessageType)numType {
    
    NSString *stringType = [self stringTypeForNumType:numType];
    
    [self saveLogMessageWithText:text
                            type:stringType];
    
}

- (void)saveLogMessageWithText:(NSString *)text {
    [self saveLogMessageWithText:text numType:STMLogMessageTypeInfo];
}

- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type {
    [self saveLogMessageWithText:text type:type owner:nil];
}

- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type owner:(STMDatum *)owner {
    
    // owner is unused property
    owner = nil; // have to check owner.managedObjectsContext before use it
    
    if (![[self availableTypes] containsObject:type]) type = @"info";
    
    NSLog(@"Log %@: %@", type, text);
    
#ifdef DEBUG
    //    [self sendLogMessageToLocalServerForDebugWithType:type andText:text];
#endif
    
    NSArray *uploadTypes = [self syncingTypesForSettingType:self.uploadLogType];
    
    if ([uploadTypes containsObject:type]) {
        
        BOOL sessionIsRunning = (self.session.status == STMSessionRunning);
        
        NSMutableDictionary *logMessageDic = @{}.mutableCopy;
        
        logMessageDic[@"text"] = [NSString stringWithFormat:@"%@: %@", [STMFunctions stringFromNow], text];
        logMessageDic[@"type"] = type;
        
        if (sessionIsRunning && self.document) {
            
            [self createAndSaveLogMessageFromDictionary:logMessageDic];
            
        } else {
            
            logMessageDic[@"deviceCts"] = [NSDate date];
            
            [self performSelector:@selector(saveLogMessageDictionary:)
                       withObject:logMessageDic
                       afterDelay:0];
            
        }
        
    }
    
}


#pragma mark - Private

- (id)persistenceDelegate {
    return self.session.persistenceDelegate;
}

- (void)saveLogMessageDictionary:(NSDictionary *)logMessageDic {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSArray *loggerDefaults = [defaults arrayForKey:[self loggerKey]];
    NSMutableArray *loggerDefaultsMutable = (loggerDefaults) ? loggerDefaults.mutableCopy : @[].mutableCopy;
    
    //    NSString *type = logMessageDic[@"type"];
    //    NSPredicate *typePredicate = [NSPredicate predicateWithFormat:@"type == %@", type];
    //    NSMutableDictionary *lastLogMessage = [loggerDefaultsMutable filteredArrayUsingPredicate:typePredicate].lastObject;
    //
    //    NSDictionary *logMessageToStore = [self logMessageToStoreWithLastLogMessage:lastLogMessage
    //                                                               andLogMessageDic:logMessageDic];
    //
    //    [loggerDefaultsMutable removeObject:lastLogMessage];
    //    [loggerDefaultsMutable addObject:logMessageToStore];
    
    [loggerDefaultsMutable addObject:logMessageDic];
    
    [defaults setObject:loggerDefaultsMutable forKey:[self loggerKey]];
    [defaults synchronize];
    
}

- (NSDictionary *)logMessageToStoreWithLastLogMessage:(NSDictionary *)lastLogMessage andLogMessageDic:(NSDictionary *)logMessageDic {
    
    if (lastLogMessage) {
        
        NSMutableDictionary *logMessageToStore = lastLogMessage.mutableCopy;
        
        NSString *text = lastLogMessage[@"text"];
        text = [text stringByAppendingString:@"\n"];
        text = [text stringByAppendingString:logMessageDic[@"text"]];
        
        logMessageToStore[@"text"] = text;
        
        return logMessageToStore;
        
    } else {
        
        return logMessageDic;
        
    }
    
}

- (NSArray *)availableTypes {
    return @[@"important", @"error", @"warning", @"info", @"debug"];
}


- (void)createAndSaveLogMessageFromDictionary:(NSDictionary *)logMessageDic {
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    [self.session.persistenceDelegate mergeAsync:NSStringFromClass([STMLogMessage class])
                                      attributes:logMessageDic
                                         options:options
                               completionHandler:nil];
    
    //    NSString *type = logMessageDic[@"type"];
    //
    //    NSPredicate *unsyncedPredicate = [STMFunctions predicateForUnsyncedObjectsWithEntityName:@"STMLogMessage"];
    //    NSPredicate *typePredicate = [NSPredicate predicateWithFormat:@"type == %@", type];
    //
    //    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[unsyncedPredicate, typePredicate]];
    //
    //    NSDictionary *options = @{STMPersistingOptionPageSize   : @1,
    //                              STMPersistingOptionOrder      : @"deviceCts",
    //                              STMPersistingOptionOrderDirectionAsc};
    //
    //    [self.session.persistenceDelegate findAllAsync:@"STMLogMessage" predicate:predicate options:options completionHandler:^(BOOL success, NSArray <NSDictionary *> *result, NSError *error) {
    //
    //        NSDictionary *lastUnsyncedLogMessage = result.lastObject;
    //
    //        NSDictionary *logMessageToStore = [self logMessageToStoreWithLastLogMessage:lastUnsyncedLogMessage
    //                                                                   andLogMessageDic:logMessageDic];
    //
    //        NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    //
    //        [self.session.persistenceDelegate mergeAsync:NSStringFromClass([STMLogMessage class])
    //                                          attributes:logMessageToStore
    //                                             options:options
    //                                   completionHandler:nil];
    //    
    //    }];
    
}

- (void)requestInfo:(NSString *)xidString {
    
    if ([xidString isEqual:[NSNull null]]) {
        NSString *logMessage = [NSString stringWithFormat:@"xidSting is NSNull"];
        return [self saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
    }
    
    NSDictionary *object = [STMCoreObjectsController objectForIdentifier:xidString];
    
    if (!object) {
        NSString *logMessage = [NSString stringWithFormat:@"no object with xid %@", xidString];
        return [self saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
    }
    
    [self saveLogMessageWithText:[STMFunctions jsonStringFromDictionary:object]
                         numType:STMLogMessageTypeImportant];
    
}


- (void)requestObjects:(NSDictionary *)parameters {
    
    NSError *error;
    
    NSArray *jsonArray = [self jsonForObjectsWithParameters:parameters error:&error];
    
    if (error) {
        
        return [self saveLogMessageWithText:error.localizedDescription numType:STMLogMessageTypeError];
    }
    
    NSDictionary *jsonDic = @{@"objects": jsonArray,
                              @"requestParameters": parameters};
    
    [self saveLogMessageWithText:[STMFunctions jsonStringFromDictionary:jsonDic]
                         numType:STMLogMessageTypeImportant];
    
}


- (void)requestDefaults {
    
    NSDictionary *defaultsDic = @{@"userDefault": [STMUserDefaults standardUserDefaults].dictionaryRepresentation};
    
    if (defaultsDic) {
        
        NSString *JSONString = [STMFunctions jsonStringFromDictionary:defaultsDic];
        
        [self saveLogMessageWithText:JSONString
                             numType:STMLogMessageTypeImportant];
        
    }
}

- (void)saveLogMessageDictionaryToDocument {
    
    NSLog(@"saveLogMessageDictionaryToDocument");
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSArray *loggerDefaults = [defaults arrayForKey:[self loggerKey]];
    
    for (NSDictionary *logMessageDic in loggerDefaults) {
        [self createAndSaveLogMessageFromDictionary:logMessageDic];
    }
    
    [defaults removeObjectForKey:[self loggerKey]];
    [defaults synchronize];
    
}

- (void)sendLogMessageToLocalServerForDebugWithType:(NSString *)type andText:(NSString *)text {
    
    NSURL *url = [NSURL URLWithString:@"http://maxbook.local:8888"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    
    NSString *bodyString = [NSString stringWithFormat:@"%@ %@: %@", [dateFormatter stringFromDate:[NSDate date]], type, text];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        //            NSLog(@"%@", response);
    }];
    
}


- (NSArray *)jsonForObjectsWithParameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error {
    
    NSString *errorMessage = nil;
    
    if ([parameters isKindOfClass:[NSDictionary class]] && parameters[@"entityName"] && [parameters[@"entityName"] isKindOfClass:[NSString class]]) {
        
        NSString *entityName = [STMFunctions addPrefixToEntityName:(NSString * _Nonnull)parameters[@"entityName"]];
        
        BOOL sessionIsRunning = (self.session.status == STMSessionRunning);
        if (sessionIsRunning && self.document) {
            
            return [self.persistenceDelegate findAllSync:entityName predicate:nil options:parameters error:error];
            
            
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"session is not running, please try later"];
            
        }
        
    } else {
        
        errorMessage = [NSString stringWithFormat:@"requestObjects: parameters is not NSDictionary"];
        
    }
    
    if (errorMessage) [STMFunctions error:error withMessage:errorMessage];
    
    return nil;
    
}

@end