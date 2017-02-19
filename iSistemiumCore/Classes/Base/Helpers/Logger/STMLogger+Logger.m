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
#import "STMUserDefaults.h"
#import "STMLogMessage.h"

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
    
    if (!text) return;
    
    // owner is unused property
    owner = nil; // have to check owner.managedObjectsContext before use it
    
    if (![[self availableTypes] containsObject:type]) type = @"info";
    
#ifdef DEBUG
    //    [self sendLogMessageToLocalServerForDebugWithType:type andText:text];
#endif
    
    NSArray *uploadTypes = [self syncingTypesForSettingType:self.uploadLogType];
    
    if ([uploadTypes containsObject:type]) {
        
        NSArray *result = [self checkMessageForRepeatingPattern:@{@"text"  : text,
                                                                  @"type"  : type}];

        if (!result) return;
        
        for (NSDictionary *logMessageDic in result) {
            
            NSLog(@"Log %@: %@", logMessageDic[@"type"], logMessageDic[@"text"]);
            
            [self saveLogMessageDic:logMessageDic];
            
        }
        
    } else {
        
        NSLog(@"Log %@: %@", type, text);

    }
    
}

- (void)saveLogMessageDic:(NSDictionary *)logMessageDic {
    
    BOOL sessionIsRunning = (self.session.status == STMSessionRunning);

    if (sessionIsRunning && self.document) {
        
        [self createAndSaveLogMessageFromDictionary:logMessageDic];
        
    } else {
        
        NSMutableDictionary *lmd = logMessageDic.mutableCopy;
        lmd[@"deviceCts"] = [NSDate date];
        
        [self performSelector:@selector(saveLogMessageDictionary:)
                   withObject:lmd
                   afterDelay:0];
        
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


#pragma mark - check repeated patterns

- (NSArray *)checkMessageForRepeatingPattern:(NSDictionary *)logMessageDic {

    NSDate *now = [NSDate date];

    if (self.lastLogMessageDate) {
        
        NSTimeInterval timeInterval = [now timeIntervalSinceDate:self.lastLogMessageDate];
        
        if (timeInterval > MESSAGE_DELAY_TO_CHECK_PATTERN) {

            self.lastLogMessageDate = now;

            return self.patternDetected ? [self endPatternDetectionWith:logMessageDic] : [self releasePossiblePatternArrayWith:logMessageDic];
            
        }
        
    }
    
    self.lastLogMessageDate = now;
    
    if (!self.lastLogMessagesArray) self.lastLogMessagesArray = @[].mutableCopy;
    if (!self.possiblePatternArray) self.possiblePatternArray = @[].mutableCopy;

    if (!self.patternDetected) {
        
        return [self checkPatternWith:logMessageDic];

    } else {
        
        return [self checkPatternEndsWith:logMessageDic];
        
    }

}

- (NSArray *)checkPatternWith:(NSDictionary *)logMessageDic {
    
    NSUInteger lastPatternLogMessageIndex = [self.lastLogMessagesArray indexOfObject:self.possiblePatternArray.lastObject];
    
    if (lastPatternLogMessageIndex == NSNotFound) {
        
        return [self checkPatternStartWith:logMessageDic];
        
    } else {
        
        return [self checkPatternContinueWith:logMessageDic
                                    checkIndex:lastPatternLogMessageIndex + 1];
        
    }

}

- (NSArray *)checkPatternStartWith:(NSDictionary *)logMessageDic {
    
    if ([self.lastLogMessagesArray containsObject:logMessageDic]) {
        
        return [self enqueuePossiblePatternLogMessage:logMessageDic];
        
    } else {
        
        [self enqueueLogMessage:logMessageDic];
        return @[logMessageDic];
        
    }

}

- (NSArray *)checkPatternContinueWith:(NSDictionary *)logMessageDic checkIndex:(NSUInteger)checkIndex {

    if (self.lastLogMessagesArray.count > checkIndex && [[self.lastLogMessagesArray objectAtIndex:checkIndex] isEqualToDictionary:logMessageDic]) {
        
        return [self enqueuePossiblePatternLogMessage:logMessageDic];
        
    } else {
        
        return [self releasePossiblePatternArrayWith:logMessageDic];
        
    }

}

- (NSArray *)releasePossiblePatternArrayWith:(NSDictionary *)logMessageDic {
    
    NSMutableArray *returnArray = self.possiblePatternArray.mutableCopy;
    
    for (NSDictionary *logMessage in self.possiblePatternArray) {
        [self enqueueLogMessage:logMessage];
    }
    
    [self enqueueLogMessage:logMessageDic];
    [returnArray addObject:logMessageDic];
    
    [self.possiblePatternArray removeAllObjects];
    
    return returnArray;

}

- (NSArray *)checkPatternEndsWith:(NSDictionary *)logMessageDic {
    
    if (![self.possiblePatternArray[self.currentPatternIndex] isEqualToDictionary:logMessageDic]) {
        return [self endPatternDetectionWith:logMessageDic];
    }
    
    BOOL isLastIndex = (self.currentPatternIndex == self.possiblePatternArray.count - 1);
    
    if (isLastIndex) self.patternRepeatCounter++;

    isLastIndex ? self.currentPatternIndex = 0 : self.currentPatternIndex++;

    return nil;

}

- (NSArray *)endPatternDetectionWith:(NSDictionary *)logMessageDic {
    
    self.patternDetected = NO;
    
    NSRange returnRange = NSMakeRange(0, self.currentPatternIndex);
    
    NSMutableArray *returnArray = [self.possiblePatternArray subarrayWithRange:returnRange].mutableCopy;
    
    for (NSDictionary *logMessage in returnArray) {
        [self enqueueLogMessage:logMessage];
    }
    
    [self enqueueLogMessage:logMessageDic];
    [self.possiblePatternArray removeAllObjects];
    
    NSDictionary *result = @{@"type"    : @"important",
                             @"text"    : [NSString stringWithFormat:@"detect end of pattern, repeat %@ times", @(self.patternRepeatCounter)]};
    
    [returnArray insertObject:result atIndex:0];
    [returnArray addObject:logMessageDic];
    
//    NSLog(@"returnArray %@", returnArray);
    
    return returnArray;

}

- (void)enqueueLogMessage:(NSDictionary *)logMessageDictionary {
    
    [self.lastLogMessagesArray addObject:logMessageDictionary];
    
    if (self.lastLogMessagesArray.count > self.patternDepth) {
        [self.lastLogMessagesArray removeObjectAtIndex:0];
    }
    
}

- (NSArray *)enqueuePossiblePatternLogMessage:(NSDictionary *)logMessageDictionary {
    
    [self.possiblePatternArray addObject:logMessageDictionary];
    
    NSRange checkRange = NSMakeRange(self.lastLogMessagesArray.count - self.possiblePatternArray.count, self.possiblePatternArray.count);
    
    NSArray *arrayToCheck = [self.lastLogMessagesArray subarrayWithRange:checkRange];
    
    if ([arrayToCheck isEqualToArray:self.possiblePatternArray]) {
        
        self.patternDetected = YES;
        self.currentPatternIndex = 0;
        self.patternRepeatCounter = 1;

        NSDictionary *result = @{@"type"    : @"error",
                                 @"text"    : [NSString stringWithFormat:@"detect repeating pattern with last %@ logMessages", @(self.possiblePatternArray.count)]};

        return @[result];

    }
    
    return nil;
    
}


@end
