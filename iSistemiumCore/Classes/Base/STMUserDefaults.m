//
//  STMUserDefaults.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 26/07/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMUserDefaults.h"

#import "STMFunctions.h"
#import "STMLogger.h"


#define STM_USER_DEFAULTS_URL @"stmUserDefaults"


@interface STMUserDefaults()

@property (nonatomic, strong) NSMutableDictionary *defaultsDic;
@property (nonatomic, strong) NSURL *defaultsUrl;


@end


@implementation STMUserDefaults

+ (instancetype)standardUserDefaults {
	
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;

}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self loadDefaults];
    }
    return self;
    
}

- (NSURL *)defaultsUrl {
    
    if (!_defaultsUrl) {
        
        NSURL *documentsUrl = [STMFunctions documentsDirectoryURL];
        _defaultsUrl = [documentsUrl URLByAppendingPathComponent:STM_USER_DEFAULTS_URL];
        
    }
    return _defaultsUrl;
    
}

- (NSMutableDictionary *)defaultsDic {
    
    if (!_defaultsDic) {
        [self loadDefaults];
    }
    return _defaultsDic;
    
}

- (void)loadDefaults {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (self.defaultsUrl.path) {
        
        if (![fileManager fileExistsAtPath:(NSString *)self.defaultsUrl.path]) {
            
            self.defaultsDic = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation].mutableCopy;
            
            [self synchronize];
            
        } else {
            
            NSError *error = nil;

            NSData *defaultsData = [NSData dataWithContentsOfURL:self.defaultsUrl
                                                         options:0
                                                           error:&error];
            
            if (error) {
                
                NSString *logMessage = [NSString stringWithFormat:@"can't load defaults from url %@, flush userDefaults", self.defaultsUrl];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                         numType:STMLogMessageTypeError];
                [[STMLogger sharedLogger] saveLogMessageWithText:error.localizedDescription
                                                         numType:STMLogMessageTypeError];
                
                [self flushUserDefaults];

            } else {
                
                id unarchiveObject = [NSKeyedUnarchiver unarchiveObjectWithData:defaultsData];
                
                if ([unarchiveObject isKindOfClass:[NSDictionary class]]) {
                
                    self.defaultsDic = (NSMutableDictionary*)unarchiveObject;

                } else {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"load userDefaults from file: unarchiveObject is not NSDictionary class, flush userDefaults"];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                             numType:STMLogMessageTypeError];
                    
                    [self flushUserDefaults];

                }
                
            }
            
        }
        
    } else {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:@"defaults url.path is null"
                                                 numType:STMLogMessageTypeError];
        
    }
    
}

- (void)flushUserDefaults {

    self.defaultsDic = @{}.mutableCopy;
    [self synchronize];

}

- (BOOL)synchronize {
    
    NSData *defaultsData = [NSKeyedArchiver archivedDataWithRootObject:self.defaultsDic];
    
    NSError *error;
    
    BOOL writeResult = [defaultsData writeToURL:self.defaultsUrl
                                        options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                          error:&error];
    
    if (!writeResult) {
        
        NSString *logMessage = [NSString stringWithFormat:@"can't write defaults to url %@", self.defaultsUrl];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];

        [[STMLogger sharedLogger] saveLogMessageWithText:error.localizedDescription
                                                 numType:STMLogMessageTypeError];

    }

    return writeResult;
    
}

- (NSDictionary<NSString *,id> *)dictionaryRepresentation {
    return self.defaultsDic;
}

- (NSArray *)arrayForKey:(NSString *)defaultName {
    
    id result = [self objectForKey:defaultName];
    
    return ([result isKindOfClass:[NSArray class]]) ? result : nil;
    
}

- (id)objectForKey:(NSString *)defaultName {
    return self.defaultsDic[defaultName];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
	
    NSArray *availableClasses = @[[NSData class],
                                  [NSDate class],
                                  [NSNumber class],
                                  [NSString class],
                                  [NSArray class],
                                  [NSDictionary class]];
    
    BOOL checkPassed = NO;
    
    for (Class availableClass in availableClasses) {
        
        if ([value isKindOfClass:availableClass]) {
            
            checkPassed = YES;
            break;
            
        }
        
    }
    
    if (checkPassed) {
        
        self.defaultsDic[defaultName] = value;
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"value should be kind of classes: %@", availableClasses];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];

        
    }
    
}

- (BOOL)boolForKey:(NSString *)defaultName {
    
    id result = [self objectForKey:defaultName];
    
    if ([result respondsToSelector:@selector(boolValue)]) {
        return [result boolValue];
    } else {
        return NO;
    }
    
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
	
    NSNumber *boolNumber = [NSNumber numberWithBool:value];
    [self setObject:boolNumber forKey:defaultName];
    
}

- (NSInteger)integerForKey:(NSString *)defaultName {
	
    id result = [self objectForKey:defaultName];
    
    if ([result respondsToSelector:@selector(integerValue)]) {
        return [result integerValue];
    } else {
        return 0;
    }

}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {

    NSNumber *integerNumber = [NSNumber numberWithInteger:value];
    [self setObject:integerNumber forKey:defaultName];

}

- (void)removeObjectForKey:(NSString *)defaultName {
    [self.defaultsDic removeObjectForKey:defaultName];
}


@end
