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


#define STM_USER_DEFAULTS_PATH @"stmUserDefaults"


@interface STMUserDefaults ()

@property(nonatomic, strong) NSMutableDictionary *defaultsDic;
@property(nonatomic, strong) NSString *defaultsPath;


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

- (NSString *)defaultsPath {

    if (!_defaultsPath) {
        _defaultsPath = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:STM_USER_DEFAULTS_PATH];
    }
    return _defaultsPath;

}

- (NSMutableDictionary *)defaultsDic {

    if (!_defaultsDic) {
        [self loadDefaults];
    }
    return _defaultsDic;

}

- (void)loadDefaults {

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (self.defaultsPath) {

        if (![fileManager fileExistsAtPath:(NSString *) self.defaultsPath]) {

            self.defaultsDic = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation].mutableCopy;

            [self synchronize];

        } else {

            NSError *error = nil;

            NSData *defaultsData = [NSData dataWithContentsOfFile:self.defaultsPath
                                                          options:0
                                                            error:&error];

            if (defaultsData) {

                id unarchiveObject = [NSKeyedUnarchiver unarchiveObjectWithData:defaultsData];

                if ([unarchiveObject isKindOfClass:[NSDictionary class]]) {

                    self.defaultsDic = (NSMutableDictionary *) unarchiveObject;

                } else {

                    NSString *logMessage = [NSString stringWithFormat:@"load userDefaults from file: unarchiveObject is not NSDictionary class, flush userDefaults"];
                    [[STMLogger sharedLogger] errorMessage:logMessage];

                    [self flushUserDefaults];

                }

            } else {

                NSString *logMessage = [NSString stringWithFormat:@"can't load defaults from path %@, flush userDefaults", self.defaultsPath];
                [[STMLogger sharedLogger] errorMessage:logMessage];
                [[STMLogger sharedLogger] errorMessage:error.localizedDescription];

                [self flushUserDefaults];

            }

        }

    } else {

        [[STMLogger sharedLogger] errorMessage:@"defaults path is null"];

    }

}

- (void)flushUserDefaults {

    self.defaultsDic = @{}.mutableCopy;
    [self synchronize];

}

- (BOOL)synchronize {

    if (!self.defaultsPath) {

        [[STMLogger sharedLogger] errorMessage:@"defaults path is null"];
        return NO;

    }

    NSData *defaultsData = [NSKeyedArchiver archivedDataWithRootObject:self.defaultsDic];

    NSError *error;

    BOOL writeResult = [defaultsData writeToFile:self.defaultsPath
                                         options:(NSDataWritingAtomic | NSDataWritingFileProtectionNone)
                                           error:&error];

    if (!writeResult) {

        NSString *logMessage = [NSString stringWithFormat:@"can't write defaults to path %@", self.defaultsPath];
        [[STMLogger sharedLogger] errorMessage:logMessage];
        [[STMLogger sharedLogger] errorMessage:error.localizedDescription];

    }

    return writeResult;

}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return self.defaultsDic;
}

- (NSArray *)arrayForKey:(NSString *)defaultName {

    id result = [self objectForKey:defaultName];

    return ([result isKindOfClass:[NSArray class]]) ? result : nil;

}

- (id)objectForKey:(NSString *)defaultName {
    return self.defaultsDic[defaultName];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self setObject:value forKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {

    if (!value) {

        [self.defaultsDic removeObjectForKey:defaultName];
        return;

    }

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
