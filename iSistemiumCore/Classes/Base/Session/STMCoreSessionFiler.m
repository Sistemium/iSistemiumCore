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

#pragma mark - STMDirectoring protocol

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
    
    self.orgPath = [self basePath:self.documentsPath
                         withPath:org];

}

- (NSString *)userDocuments {
    
    return [self basePath:self.orgPath
                 withPath:self.uid];
    
}

- (NSString *)sharedDocuments {
    
    return [self basePath:self.orgPath
                 withPath:SHARED_PATH];
    
}

- (NSString *)basePath:(NSString *)basePath withPath:(NSString *)path {
    
#warning - every time we asked for userDocuments, sharedDocuments, persistencePath, picturesPath and webViewsPath we will call [fm fileExistsAtPath:] method inside [STMFunctions dirExistsOrCreateItAtPath:], have to taking it into account, it may be slow
    // for example, the picturesController will save bunch of pictures we have to store picturesPath in it's property
    // may be we need to think something else about it
    
    NSString *resultPath = [basePath stringByAppendingPathComponent:path];
    return [self dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;
    
}

- (NSBundle *)bundle {
    return [NSBundle mainBundle];
}


#pragma mark - directoring private methods

- (BOOL)dirExistsOrCreateItAtPath:(NSString *)dirPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:dirPath]) {
        
        NSError *error = nil;
        BOOL result = [fm createDirectoryAtPath:dirPath
                    withIntermediateDirectories:YES
                                     attributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                                          error:&error];
        
        if (!result) {
            
            NSLog(@"can't create directory at path: %@, error: %@", dirPath, error.localizedDescription);
            return NO;
            
        }
        
    }
    
    return YES;
    
}


#pragma mark - STMFiling protocol

@synthesize directoring = _directoring;
@synthesize fileManager = _fileManager;

- (NSFileManager *)fileManager {
    return [NSFileManager defaultManager];
}

- (NSString *)persistenceBasePath {
    
    return [self.directoring basePath:[self.directoring userDocuments]
                             withPath:PERSISTENCE_PATH];
    
}

- (NSString *)picturesBasePath {
    
    return [self.directoring basePath:[self.directoring sharedDocuments]
                             withPath:PICTURES_PATH];
    
}

- (NSString *)webViewsBasePath {
    
    return [self.directoring basePath:[self.directoring sharedDocuments]
                             withPath:WEBVIEWS_PATH];
    
}

- (NSString *)persistencePath:(NSString *)folderName {
    
    return [self.directoring basePath:[self persistenceBasePath]
                             withPath:folderName];
    
}

- (NSString *)picturesPath:(NSString *)folderName {
    
    return [self.directoring basePath:[self picturesBasePath]
                             withPath:folderName];
    
}

- (NSString *)webViewsPath:(NSString *)folderName {
    
    return [self.directoring basePath:[self webViewsBasePath]
                             withPath:folderName];
    
}

- (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error {
    
    BOOL sourceIsDir = NO;
    
    if (![self.fileManager fileExistsAtPath:sourcePath isDirectory:&sourceIsDir]) {
        return NO;
    }
    
    if ([self.fileManager fileExistsAtPath:destinationPath]) {
        if (![self removeItemAtPath:destinationPath error:error]) return NO;
    }
    
    BOOL result = [self.fileManager copyItemAtPath:sourcePath
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
    
    result = [self enumerateDirAtPath:destinationPath withBlock:^BOOL(NSString *path, NSError **enumError) {
        
        localError = *enumError; // ???
        
        return [self setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                      ofItemAtPath:path
                             error:enumError];
        
    }];
    
    *error = localError; // ???
    
    return result;
    
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    
    BOOL result = [self.fileManager removeItemAtPath:path
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
    
    NSString *momdPath = [[[self persistencePath:nil] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"momd"];
    
    if ([self.fileManager fileExistsAtPath:momdPath]) {
        return momdPath;
    }
    
    NSString *momPath = [[[self persistencePath:nil] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"mom"];
    
    if ([self.fileManager fileExistsAtPath:momPath]) {
        return momPath;
    }
    
    NSLog(@"there is no path in user's folder for data model with name %@", name);
    return nil;
    
}

- (BOOL)enumerateDirAtPath:(NSString *)dirPath withBlock:(BOOL (^)(NSString *path, NSError **error))enumDirBlock {
    
    NSDirectoryEnumerator *dirEnum = [self.fileManager enumeratorAtPath:dirPath];
    
    BOOL result = YES;
    NSError *error = nil;
    
    for (NSString *thePath in dirEnum) {
        
        NSString *fullPath = [dirPath stringByAppendingPathComponent:thePath];
        
        result = enumDirBlock(fullPath, &error);
        
        if (!result) break;
        
    }
    
    return result;
    
}


#pragma mark - filing private methods

- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error {
    
    BOOL result = [self.fileManager setAttributes:attributes
                                     ofItemAtPath:path
                                            error:error];
    
    if (!result) {
        NSLog(@"set attribute NSFileProtectionNone ofItemAtPath: %@ error: %@", path, [*error localizedDescription]);
    }
    
    return result;
    
}


@end
