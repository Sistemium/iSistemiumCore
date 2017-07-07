//
//  STMCoreSessionFiler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 03/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSessionFiler+Private.h"
#import "STMFunctions.h"
#import "STMLogger.h"

@implementation STMCoreSessionFiler

#pragma mark - STMDirectoring protocol

- (instancetype)initWithOrg:(NSString *)org userId:(NSString *)uid {
    
    self = [self init];
    
    if (!self) return nil;
    
    NSString *orgPath = [self basePath:[STMFunctions documentsDirectory] withPath:org];
    
    self.userDocuments = [self basePath:orgPath withPath:uid];
    self.sharedDocuments = [self basePath:orgPath withPath:SHARED_PATH];

    return [self initWithDirectoring:self];
    
}

- (NSBundle *)bundle {
    return [NSBundle mainBundle];
}


#pragma mark - init


+ (instancetype)coreSessionFilerWithDirectoring:(id <STMDirectoring>)directoring {
    return [[self alloc] initWithDirectoring:directoring];
}

- (instancetype)initWithDirectoring:(id <STMDirectoring>)directoring {
    self = [self init];
    self.directoring = directoring;
    return self;
}


#pragma mark - STMFiling protocol

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

- (NSString *)temporaryDirectoryPathWithPath:(NSString *)path {
    
    return [self basePath:NSTemporaryDirectory()
                 withPath:path];
    
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

- (BOOL)fileExistsAtPath:(NSString *)path{

    return [self.fileManager fileExistsAtPath:path];
    
}


#pragma mark - filing private methods

- (NSFileManager *)fileManager {
    return [NSFileManager defaultManager];
}

- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error {
    
    BOOL result = [self.fileManager setAttributes:attributes
                                     ofItemAtPath:path
                                            error:error];
    
    if (!result) {
        NSLog(@"set attribute NSFileProtectionNone ofItemAtPath: %@ error: %@", path, [*error localizedDescription]);
    }
    
    return result;
    
}

- (NSString *)basePath:(NSString *)basePath withPath:(NSString *)path {
    
    NSString *resultPath = [basePath stringByAppendingPathComponent:path];
    return [self dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;
    
}

- (BOOL)dirExistsOrCreateItAtPath:(NSString *)dirPath {
    
    // every time we ask for userDocuments, sharedDocuments, persistencePath, picturesPath or webViewsPath
    // we call [fm fileExistsAtPath:] method inside [STMFunctions dirExistsOrCreateItAtPath:]
    // TODO: rewrite all these getters with some kind of lazy instantiation to speed up
    
    NSFileManager *fm = self.fileManager;
    
    if ([fm fileExistsAtPath:dirPath]) return YES;
        
    NSError *error = nil;
    BOOL result = [fm createDirectoryAtPath:dirPath
                withIntermediateDirectories:YES
                                 attributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                                      error:&error];
    
    if (!result) {
        NSLog(@"can't create directory at path: %@, error: %@", dirPath, error.localizedDescription);
    }
    
    return result;
    
}

#pragma mark - remote controller

+ (NSDictionary *)getFileArrayforPath:(NSString*)path {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary *dictionary = @{}.mutableCopy;
    NSArray * directoryContents = [fm contentsOfDirectoryAtPath:path error:nil];
    
    for (NSString * file in directoryContents) {
        
        BOOL isDirectory = NO;
        NSString* fullPath = [path stringByAppendingPathComponent:file];
        
        [fm fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if (isDirectory){
            dictionary[file] = [self getFileArrayforPath:fullPath];
        } else {
            NSDictionary *atr = [fm attributesOfItemAtPath:fullPath error:nil];
            dictionary[file] = @{@"NSFileSize":atr[@"NSFileSize"],
                                 @"NSFileCreationDate":atr[@"NSFileCreationDate"],
                                 @"NSFileModificationDate":atr[@"NSFileModificationDate"]};
        }
        
    }
    
    return dictionary.copy;
    
}

+ (NSDictionary *)JSONOfAllFiles {

    NSDictionary* dictionary = [self getFileArrayforPath:[STMFunctions documentsDirectory]];
    
    return dictionary;

}

+ (NSDictionary *)JSONOfFilesAtPath:(NSString *)path {
    
    path = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:path];
    
    NSDictionary* dictionary = [self getFileArrayforPath:path];
    
    return dictionary;
    
}

@end
