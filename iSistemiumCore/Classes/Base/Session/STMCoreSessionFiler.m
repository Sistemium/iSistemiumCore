//
//  STMCoreSessionFiler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 03/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSessionFiler.h"

#import "STMFunctions.h"


@interface STMCoreSessionFiler()

@property (nonatomic, strong) NSString *org;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *documentsPath;
@property (nonatomic, strong) NSString *orgPath;


@end

@implementation STMCoreSessionFiler

@synthesize directoring = _directoring;
@synthesize fileManager = _fileManager;


#pragma mark - STMDirectoring

- (instancetype)initWithOrg:(NSString *)org userId:(NSString *)uid {
    
    self = [super init];
    
    if (self) {
        
        self.org = org;
        self.uid = uid;
        
    }
    return self;
    
}

- (NSString *)documentsPath {
    
    if (!_documentsPath) {
        _documentsPath = [STMFunctions documentsDirectory];
    }
    return _documentsPath;
    
}

- (void)setOrg:(NSString *)org {
    
    _org = org;
    
    self.orgPath = [self.documentsPath stringByAppendingPathComponent:org];
    
    [STMFunctions dirExistsOrCreateItAtPath:self.orgPath];
    
}

- (NSString *)userDocuments {
    
    NSString *userPath = [self.orgPath stringByAppendingPathComponent:self.uid];
    return [STMFunctions dirExistsOrCreateItAtPath:userPath] ? userPath : nil;
    
}

- (NSString *)sharedDocuments {
    
    NSString *sharedPath = [self.orgPath stringByAppendingPathComponent:SHARED_PATH];
    return [STMFunctions dirExistsOrCreateItAtPath:sharedPath] ? sharedPath : nil;
    
}

- (NSBundle *)bundle {
    return [NSBundle mainBundle];
}


#pragma mark - STMFiling

- (NSString *)persistencePath:(NSString *)folderName {
    
    return [self basePath:[self persistenceBasePath]
                 withPath:folderName];
    
}

- (NSString *)picturesPath:(NSString *)folderName {
    
    return [self basePath:[self picturesBasePath]
                 withPath:folderName];
    
}

- (NSString *)webViewsPath:(NSString *)folderName {
    
    return [self basePath:[self webViewsBasePath]
                 withPath:folderName];
    
}

- (NSString *)persistenceBasePath {
    
    return [self basePath:[self.directoring userDocuments]
                 withPath:PERSISTENCE_PATH];
    
}

- (NSString *)picturesBasePath {
    
    return [self basePath:[self.directoring sharedDocuments]
                 withPath:PICTURES_PATH];
    
}

- (NSString *)webViewsBasePath {
    
    return [self basePath:[self.directoring sharedDocuments]
                 withPath:WEBVIEWS_PATH];
    
}

- (NSString *)basePath:(NSString *)basePath withPath:(NSString *)path {
    
    NSString *resultPath = [basePath stringByAppendingPathComponent:path];
    return [STMFunctions dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;
    
}

- (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL sourceIsDir = NO;
    
    if (![fm fileExistsAtPath:sourcePath isDirectory:&sourceIsDir]) {
        return NO;
    }
    
    if ([fm fileExistsAtPath:destinationPath]) {
        if (![self removeItemAtPath:destinationPath error:error]) return NO;
    }
    
    BOOL result = [fm copyItemAtPath:sourcePath
                              toPath:destinationPath
                               error:error];
    
    if (!result) {
        
        NSLog(@"copyItemAtPath: %@ toPath: %@ error: %@", [*error localizedDescription]);
        return NO;
        
    }
    
    result = [self setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                    ofItemAtPath:destinationPath
                           error:error];
    
    if (!result) {
        return NO;
    }
    
    __block NSError *localError = nil;
    
    result = [STMFunctions enumerateDirAtPath:destinationPath withBlock:^BOOL(NSString *path, NSError **enumError) {
        
        localError = *enumError; // ???
        
        return [self setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                      ofItemAtPath:path
                             error:enumError];
        
    }];
    
    *error = localError; // ???
    
    return result;
    
}

- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL result = [fm setAttributes:attributes
                       ofItemAtPath:path
                              error:error];
    
    if (!result) {
        NSLog(@"set attribute NSFileProtectionNone ofItemAtPath: %@ error: %@", path, [*error localizedDescription]);
    }
    
    return result;
    
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL result = [fm removeItemAtPath:path
                                 error:error];
    return result;
    
}

- (NSString *)bundledModelFile:(NSString *)name {
    
    NSBundle *bundle = [self.directoring bundle];
    
    NSString *path = [bundle pathForResource:name
                                      ofType:@"momd"];
    
    if (!path) path = [bundle pathForResource:name
                                       ofType:@"mom"];
    
    if (!path) {
        
        NSLog(@"there is no path for data model with name %@", name);
        return nil;
        
    }
    
    return path;
    
}

- (NSString *)userModelFile:(NSString *)name {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *momdPath = [[[self persistencePath:nil] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"momd"];
    
    if ([fm fileExistsAtPath:momdPath]) {
        return momdPath;
    }
    
    NSString *momPath = [[[self persistencePath:nil] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"mom"];
    
    if ([fm fileExistsAtPath:momPath]) {
        return momPath;
    }
    
    NSLog(@"there is no path in user's folder for data model with name %@", name);
    return nil;
    
}


@end
