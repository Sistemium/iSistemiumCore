//
//  STMCoreAppManifestHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 15/09/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreAppManifestHandler.h"


#define LOCAL_HTML_DIR @"localHTML"
#define UPDATE_DIR @"update"
#define TEMP_DIR @"tempHTML"
#define INDEX_HTML @"index.html"


@interface STMCoreAppManifestHandler()

@property (nonatomic, strong) NSString *localHTMLDirPath;
@property (nonatomic, strong) NSString *updateDirPath;
@property (nonatomic, strong) NSString *tempHTMLDirPath;
@property (nonatomic, strong) NSString *eTagFileName;
@property (nonatomic) BOOL checkingForUpdate;


@end


@implementation STMCoreAppManifestHandler

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
    
    completePath = [STMFunctions absoluteDocumentsPathForPath:completePath];
    
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
    
    [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (error) {
        
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
    
    NSURLRequest *request = [[STMCoreAuthController authController] authenticateRequest:[NSURLRequest requestWithURL:appManifestURI]];
    
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
    
    NSString *responseETag = httpResponse.allHeaderFields[@"eTag"];
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
    
    NSError *error;
    NSArray *dirFiles = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath error:&error];
    
    if (!error) {
        
        NSArray *currentETagFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", self.eTagFileName]];
        return (currentETagFiles.count == 0);

    } else {

        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return NO;
        
    }
    
}

- (void)handleAppManifest:(NSString *)appManifest {
    
    NSMutableArray *appComponents = [appManifest componentsSeparatedByString:@"\n"].mutableCopy;
    
    [appComponents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj isKindOfClass:[NSString class]]) {
            obj = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        } else {
            obj = @"";
        }
        
        [appComponents replaceObjectAtIndex:idx withObject:obj];
        
    }];
    
    [appComponents removeObject:@""];
    [appComponents removeObject:@"favicon.ico"];
    [appComponents removeObject:@"robots.txt"];
    
    NSUInteger startIndex = [appComponents indexOfObject:@"CACHE:"] + 1;
    NSUInteger length = [appComponents indexOfObject:@"NETWORK:"] - startIndex;
    
    NSArray *filePaths = [appComponents subarrayWithRange:NSMakeRange(startIndex, length)];
    
    BOOL loadSuccess = YES;
    
    for (NSString *filePath in filePaths) {
        
        if (![self loadAppManifestFile:filePath]) {
            
            [self.owner appManifestLoadErrorText:@"something wrong with appManifest's files loading"];
            loadSuccess = NO;
            break;
            
        }
        
    }
    
    if (loadSuccess) {

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.updateDirPath error:&error];
        
        if (error) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];

        } else {

            if ([self backupLocalHTMLDir]) {
            
                self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                                    createIfNotExist:YES
                                                 shoudCleanBeforeUse:YES];
                
                if (self.localHTMLDirPath) {
                    
                    for (NSString *dirObject in dirObjects) {
                        
                        [fm moveItemAtPath:[self.updateDirPath stringByAppendingPathComponent:dirObject]
                                    toPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                                     error:&error];
                        
                        if (error) {
                            
                            [self.owner appManifestLoadErrorText:error.localizedDescription];
                            break;
                            
                        }
                        
                    }
                    
                    (error) ? [self restoreLocalHTMLDir] : [self saveETagFile];
                    
                } else {
                    [self restoreLocalHTMLDir];
                }

            }
            
        }
        
    }

}

- (BOOL)backupLocalHTMLDir {
    
    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:YES
                                     shoudCleanBeforeUse:NO];
    
    if (!self.localHTMLDirPath) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath error:&error];

    if (error) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return NO;
        
    }
    
    self.tempHTMLDirPath = [self webViewLocalDirForPath:TEMP_DIR
                                       createIfNotExist:YES
                                    shoudCleanBeforeUse:YES];
    
    if (!self.tempHTMLDirPath) return NO;

    for (NSString *dirObject in dirObjects) {
        
        [fm moveItemAtPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                    toPath:[self.tempHTMLDirPath stringByAppendingPathComponent:dirObject]
                     error:&error];
        
        if (error) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];
            break;
            
        }
        
    }

    if (error) return NO;
    
    return YES;
    
}

- (void)restoreLocalHTMLDir {
    
    self.tempHTMLDirPath = [self webViewLocalDirForPath:TEMP_DIR
                                       createIfNotExist:NO
                                    shoudCleanBeforeUse:NO];
    
    if (!self.tempHTMLDirPath) return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.tempHTMLDirPath error:&error];
    
    if (error) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        return;
        
    }

    self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:YES
                                     shoudCleanBeforeUse:YES];
    
    if (!self.localHTMLDirPath) return;

    for (NSString *dirObject in dirObjects) {
        
        [fm moveItemAtPath:[self.tempHTMLDirPath stringByAppendingPathComponent:dirObject]
                    toPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                     error:&error];
        
        if (error) {
            
            [self.owner appManifestLoadErrorText:error.localizedDescription];
            break;
            
        }
        
    }

}

- (void)saveETagFile {
    
    NSError *error = nil;
    
    NSData *eTagFileData = [NSData data];
    
    NSString *eTagFilePath = [self.localHTMLDirPath stringByAppendingPathComponent:self.eTagFileName];
    
    [eTagFileData writeToFile:eTagFilePath
                      options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                        error:&error];
    
    if (error) {
        
        [self.owner appManifestLoadErrorText:error.localizedDescription];
        [self restoreLocalHTMLDir];
        
    } else {
        
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
        
    }

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
    
    NSURL *baseURL = [NSURL URLWithString:[self.owner webViewAppManifestURI]].URLByDeletingLastPathComponent;
    NSURL *fileURL = [baseURL URLByAppendingPathComponent:filePath];
    
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    NSString *localFilePath = [self.updateDirPath stringByAppendingPathComponent:filePath];
    
    NSError *error = nil;
    
    [fileData writeToFile:localFilePath
                  options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                    error:&error];
    
    if (error) {
        
        NSLog(@"%@", error.localizedDescription);
        return NO;
        
    } else {
        
        return YES;
        
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
        
        NSError *error = nil;
        NSString *indexHTMLString = [NSString stringWithContentsOfFile:indexHTMLPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
        
        NSString *relativePath = [self completeRelativePathForPath:LOCAL_HTML_DIR];
        NSString *completeTempPath = [STMFunctions absoluteTemporaryPathForPath:relativePath];
        
        if (!error && [fm fileExistsAtPath:completeTempPath]) {
            
            [fm removeItemAtPath:completeTempPath
                           error:&error];
            
        }

        if (!error) {
            
            [fm createDirectoryAtPath:completeTempPath
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            
        }
        
        NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath error:&error];
        
        if (!error) {

            for (NSString *dirObject in dirObjects) {
                
                [fm copyItemAtPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                            toPath:[completeTempPath stringByAppendingPathComponent:dirObject]
                             error:&error];
                
                if (error) break;
                
            }
            
        }

        if (!error) {
            
            [self.owner loadHTML:indexHTMLString
                       atBaseDir:completeTempPath];
            
        } else {

            [self.owner appManifestLoadErrorText:error.localizedDescription];
            return;

        }

    } else {
        if (!self.checkingForUpdate) [self.owner appManifestLoadErrorText:@"have no index.html"];
    }
    
}


@end
