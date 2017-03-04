//
//  STMCoreAppManifestHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 15/09/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreAppManifestHandler.h"

#import "STMCoreSessionManager.h"

#define LOCAL_HTML_DIR @"localHTML"
#define UPDATE_DIR @"update"
#define TEMP_DIR @"tempHTML"
#define INDEX_HTML @"index.html"

#define MANIFEST_CACHE_MANIFEST_LINE @"CACHE MANIFEST"
#define MANIFEST_CACHE_LINE @"CACHE:"
#define MANIFEST_NETWORK_LINE @"NETWORK:"
#define MANIFEST_FALLBACK_LINE @"FALLBACK:"

@interface STMCoreAppManifestHandler()

@property (nonatomic, strong) NSString *localHTMLDirPath;
@property (nonatomic, strong) NSString *updateDirPath;
@property (nonatomic, strong) NSString *tempHTMLDirPath;
@property (nonatomic, strong) NSString *eTagFileName;
@property (nonatomic) BOOL checkingForUpdate;


@end


@implementation STMCoreAppManifestHandler

- (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

- (NSString *)completeRelativePathForPath:(NSString *)path {
    
    if (!path) path = @"";
    
    NSString *ownerName = [self.owner webViewStoryboardParameters][@"name"];
    NSString *ownerTitle = [self.owner webViewStoryboardParameters][@"title"];
    
    NSString *completePath = [NSString pathWithComponents:@[ownerName, ownerTitle, path]];

    return completePath;
    
}

#pragma mark - directories

- (NSString *)webViewLocalDirForPath:(NSString *)dirPath createIfNotExist:(BOOL)createIfNotExist shoudCleanBeforeUse:(BOOL)cleanBeforeUse {
    
    NSString *completePath = [self completeRelativePathForPath:dirPath];
    
    completePath = (SYSTEM_VERSION < 9.0) ? [STMFunctions absoluteDocumentsPathForPath:completePath] : [STMFunctions absoluteDataCachePathForPath:completePath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL isDir;
    
    if ([fm fileExistsAtPath:completePath isDirectory:&isDir]) {
        
        if (isDir) {
            
            return (cleanBeforeUse) ? [self cleanDirAtPath:completePath] : completePath;
            
        } else {
            
            NSString *errorMessage = [NSString stringWithFormat:@"%@ dir path is not a dir", dirPath];
            [self.owner appManifestLoadErrorText:errorMessage];
            return nil;
            
        }
        
    } else {
        return [self createDirAtPath:completePath];
    }

}

- (NSString *)cleanDirAtPath:(NSString *)dirPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];

    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:dirPath];
    NSError *error = nil;
    BOOL success = YES;
    NSString *dirObject;
    
    while (dirObject = [dirEnum nextObject]) {
        
        success &= [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:dirObject] error:&error];
        
        if (!success && error) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];
            break;
            
        }
        
    }
    return (success) ? dirPath : nil;

}

- (NSString *)createDirAtPath:(NSString *)dirPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *error = nil;
    
    BOOL result = [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (!result) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return nil;
        
    }
    
    return dirPath;
    
}


#pragma mark - localHTML

- (void)startLoadLocalHTML {
    
    self.checkingForUpdate = YES;
    
    [self loadLocalHTML];
    
    NSURL *appManifestURI = [NSURL URLWithString:[self.owner webViewAppManifestURI]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:appManifestURI
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:15];
    
    request = [[self session].authDelegate authenticateRequest:request];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        
        [self handleAppManifestResponse:response
                                   data:data
                                  error:connectionError];
        
    }];

}

- (void)handleAppManifestResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)connectionError {
    
    if (connectionError) {
        
        [self.owner appManifestLoadErrorText:connectionError.localizedDescription];
        return;
        
    }

    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {

        [self.owner appManifestLoadErrorText:@"response is not a NSHTTPURLResponse class, can not get eTag"];
        return;

    }
    
    if (data.length == 0) {

        [self.owner appManifestLoadErrorText:@"response data length is 0"];
        return;

    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    if (httpResponse.statusCode != 200) {

        [self.owner appManifestLoadErrorText:[NSString stringWithFormat:@"response status code %@", @(httpResponse.statusCode)]];
        return;

    }
    
    NSString *responseETag = httpResponse.allHeaderFields[@"eTag"];
    
    if (!responseETag) {
        
        [self.owner appManifestLoadErrorText:@"response have no eTag"];
        return;

    }
    
    self.eTagFileName = [responseETag stringByAppendingString:@".eTag"];

    if ([self shouldUpdateLocalHTML]) {
        
        [self.owner appManifestLoadInfoText:@"update available"];

        self.updateDirPath = [self webViewLocalDirForPath:UPDATE_DIR
                                         createIfNotExist:YES
                                      shoudCleanBeforeUse:YES];
        
        if (self.updateDirPath) {
            
            NSString *appManifest = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            if (!appManifest) {
                
                [self.owner appManifestLoadErrorText:@"can not convert appManifest response data to string"];
                return;
                
            }
            
            [self handleAppManifest:appManifest];
            
        }

    } else {
        [self.owner appManifestLoadInfoText:@"have no update"];
    }
    
}

- (BOOL)shouldUpdateLocalHTML {
    
    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:NO
                                     shoudCleanBeforeUse:NO];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *dirFiles = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath
                                                error:&error];
    
    if (dirFiles) {
        
        NSArray *currentETagFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", self.eTagFileName]];
        return (currentETagFiles.count == 0);

    } else {

        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return NO;
        
    }
    
}

- (void)handleAppManifest:(NSString *)appManifest {
    
    NSArray *filePaths = [self filePathsToLoadFromAppManifest:appManifest];
    
    if (filePaths) {
        
        BOOL loadSuccess = YES;
        
        for (NSString *filePath in filePaths) {
            
            if (![self loadAppManifestFile:filePath]) {
                
                [self.owner appManifestLoadErrorText:@"something wrong with appManifest's files loading"];
                loadSuccess = NO;
                break;
                
            }
            
        }
        
        if (loadSuccess) {
            [self moveUpdateDirContentToLocalHTMLDir];
        }

    }
    
}

- (NSArray *)filePathsToLoadFromAppManifest:(NSString *)appManifest {
    
    NSMutableArray *manifestLines = [appManifest componentsSeparatedByString:@"\n"].mutableCopy;
    
    [manifestLines enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj isKindOfClass:[NSString class]]) {
            
            obj = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([obj hasPrefix:@"#"]) obj = @"";
            
        } else {
            
            obj = @"";
            
        }
        
        [manifestLines replaceObjectAtIndex:idx withObject:obj];
        
    }];
    
    [manifestLines removeObject:@""];
    [manifestLines removeObject:@"favicon.ico"];
    [manifestLines removeObject:@"robots.txt"];
    
    NSUInteger cacheManifestLineIndex = [manifestLines indexOfObject:MANIFEST_CACHE_MANIFEST_LINE];
    
    if (cacheManifestLineIndex == NSNotFound) {
        
        [self.owner appManifestLoadErrorText:[NSString stringWithFormat:@"'%@' line is required but not found", MANIFEST_CACHE_MANIFEST_LINE]];
        return nil;
        
    }

    if (cacheManifestLineIndex != 0) {
        
        [self.owner appManifestLoadErrorText:[NSString stringWithFormat:@"'%@' line must be the first line in cache manifest file", MANIFEST_CACHE_MANIFEST_LINE]];
        return nil;
        
    }

    NSMutableArray *cutLines = @[MANIFEST_CACHE_LINE, MANIFEST_NETWORK_LINE, MANIFEST_FALLBACK_LINE].mutableCopy;

    NSArray *filePaths = [self filePathsFromManifestLines:manifestLines
                                                 cutLines:cutLines
                                               startIndex:cacheManifestLineIndex + 1];

    NSUInteger cacheLineIndex = [manifestLines indexOfObject:MANIFEST_CACHE_LINE];
    
    if (cacheLineIndex != NSNotFound) {
        
        [cutLines removeObject:MANIFEST_CACHE_LINE];

        filePaths = [filePaths arrayByAddingObjectsFromArray:[self filePathsFromManifestLines:manifestLines
                                                                                     cutLines:cutLines
                                                                                   startIndex:cacheLineIndex + 1]];

    }
    
    return filePaths;
    
}

- (NSArray *)filePathsFromManifestLines:(NSArray *)manifestLines cutLines:(NSArray *)cutLines startIndex:(NSUInteger)startIndex {
    
    NSUInteger finishIndex = manifestLines.count - 1;
    
    for (NSString *cutLine in cutLines) {
        
        NSUInteger cutIndex = [manifestLines indexOfObject:cutLine];
        
        finishIndex = (cutIndex != NSNotFound && cutIndex >= startIndex && cutIndex <= finishIndex) ? cutIndex : finishIndex;
        
    }
    
    NSUInteger length = finishIndex - startIndex;
    
    NSArray *filePaths = [manifestLines subarrayWithRange:NSMakeRange(startIndex, length)];

    return filePaths;
    
}

- (BOOL)loadAppManifestFile:(NSString *)filePath {
    
    if (filePath.pathComponents.count > 1) {
        
        NSMutableArray *filePathComponents = filePath.pathComponents.mutableCopy;
        
        [filePathComponents removeLastObject];
        
        NSString *dirPath = [self.updateDirPath stringByAppendingPathComponent:[NSString pathWithComponents:filePathComponents]];
        
        [self createDirAtPath:dirPath];
        
    }
    
    return [self loadAndWriteFile:filePath];
    
}

- (BOOL)loadAndWriteFile:(NSString *)filePath {
    
    NSLog(@"load %@", filePath);
    
    NSURL *baseURL = [NSURL URLWithString:[self.owner webViewAppManifestURI]].URLByDeletingLastPathComponent;
    NSURL *fileURL = [baseURL URLByAppendingPathComponent:filePath];
    
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    NSString *localFilePath = [self.updateDirPath stringByAppendingPathComponent:filePath];
    
    NSError *error = nil;
    
    BOOL result = [fileData writeToFile:localFilePath
                                options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                  error:&error];
    
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    
    return result;
    
}

- (void)moveUpdateDirContentToLocalHTMLDir {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.updateDirPath error:&error];
    
    if (dirObjects) {
        
        if ([self backupLocalHTMLDir]) {
            
            self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                                createIfNotExist:YES
                                             shoudCleanBeforeUse:YES];
            
            if (self.localHTMLDirPath) {
                
                error = nil;
                
                for (NSString *dirObject in dirObjects) {
                    
                    BOOL result = [fm moveItemAtPath:[self.updateDirPath stringByAppendingPathComponent:dirObject]
                                              toPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                                               error:&error];
                    
                    if (!result) {
                        
                        [self.owner appManifestLoadErrorText:error.localizedDescription];
                        break;
                        
                    }
                    
                }
                
                (error) ? [self restoreLocalHTMLDir] : [self saveETagFile];
                
            } else {
                [self restoreLocalHTMLDir];
            }
            
        }

    } else {
        [self.owner appManifestLoadErrorText:error.localizedDescription];
    }

}

- (BOOL)backupLocalHTMLDir {
    
    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:YES
                                     shoudCleanBeforeUse:NO];
    
    if (!self.localHTMLDirPath) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath
                                                  error:&error];

    if (!dirObjects) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return NO;
        
    }
    
    self.tempHTMLDirPath = [self webViewLocalDirForPath:TEMP_DIR
                                       createIfNotExist:YES
                                    shoudCleanBeforeUse:YES];
    
    if (!self.tempHTMLDirPath) return NO;

    BOOL result = YES;
    
    for (NSString *dirObject in dirObjects) {
        
        result = [fm moveItemAtPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                             toPath:[self.tempHTMLDirPath stringByAppendingPathComponent:dirObject]
                              error:&error];
        
        if (!result) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];
            break;
            
        }
        
    }

    return result;
    
}

- (void)restoreLocalHTMLDir {
    
    self.tempHTMLDirPath = [self webViewLocalDirForPath:TEMP_DIR
                                       createIfNotExist:NO
                                    shoudCleanBeforeUse:NO];
    
    if (!self.tempHTMLDirPath) return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.tempHTMLDirPath
                                                  error:&error];
    
    if (!dirObjects) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return;
        
    }

    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:YES
                                     shoudCleanBeforeUse:YES];
    
    if (!self.localHTMLDirPath) return;

    for (NSString *dirObject in dirObjects) {
        
        BOOL result = [fm moveItemAtPath:[self.tempHTMLDirPath stringByAppendingPathComponent:dirObject]
                                  toPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                                   error:&error];
        
        if (!result) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];
            break;
            
        }
        
    }

}

- (void)saveETagFile {
    
    NSError *error = nil;
    
    NSData *eTagFileData = [NSData data];
    
    NSString *eTagFilePath = [self.localHTMLDirPath stringByAppendingPathComponent:self.eTagFileName];
    
    BOOL result = [eTagFileData writeToFile:eTagFilePath
                                    options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                      error:&error];
    
    if (result) {
        
        self.tempHTMLDirPath = [self webViewLocalDirForPath:TEMP_DIR
                                           createIfNotExist:NO
                                        shoudCleanBeforeUse:NO];
        
        if (self.tempHTMLDirPath) [self cleanDirAtPath:self.tempHTMLDirPath];
        
        self.checkingForUpdate = NO;
        
        if (self.owner.haveLocalHTML) {
            [self.owner localHTMLUpdateIsAvailable];
        } else {
            [self loadLocalHTML];
        }
        
    } else {

        [self.owner appManifestLoadErrorText:error.localizedDescription];
        [self restoreLocalHTMLDir];

    }

}

- (void)loadLocalHTML {
    
    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:NO
                                     shoudCleanBeforeUse:NO];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *indexHTMLPath = [self.localHTMLDirPath stringByAppendingPathComponent:INDEX_HTML];
    
    self.owner.haveLocalHTML = [fm fileExistsAtPath:indexHTMLPath];
    
    if (self.owner.haveLocalHTML) {
        
        BOOL result = YES;
        NSError *error = nil;
        NSString *indexHTMLString = [NSString stringWithContentsOfFile:indexHTMLPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
        
        NSString *relativePath = [self completeRelativePathForPath:LOCAL_HTML_DIR];
        NSString *completeTempPath = [STMFunctions absoluteTemporaryPathForPath:relativePath];
        
        if (indexHTMLString && [fm fileExistsAtPath:completeTempPath]) {
            
            result = [fm removeItemAtPath:completeTempPath
                                    error:&error];
            
        }
        
        if (SYSTEM_VERSION < 9.0) {

            if (result) {
                
                result = [fm createDirectoryAtPath:completeTempPath
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:&error];
                
            }
            
            if (result) {
                
                NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath error:&error];
                
                if (dirObjects) {
                    
                    for (NSString *dirObject in dirObjects) {
                        
                        result = [fm copyItemAtPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                                             toPath:[completeTempPath stringByAppendingPathComponent:dirObject]
                                              error:&error];
                        
                        if (!result) break;
                        
                    }
                    
                }
                
            }

        }
        
        if (result) {
            
            if (SYSTEM_VERSION < 9.0) {

                [self.owner loadHTML:indexHTMLString
                           atBaseDir:completeTempPath];
                
            } else {
                
                [self.owner loadUrl:[NSURL fileURLWithPath:indexHTMLPath]
                          atBaseDir:[STMFunctions absoluteDataCachePath]];
                
            }
            
        } else {
            [self.owner appManifestLoadErrorText:error.localizedDescription];
        }

    } else {
        if (!self.checkingForUpdate) [self.owner appManifestLoadErrorText:@"have no index.html"];
    }
    
}


@end
