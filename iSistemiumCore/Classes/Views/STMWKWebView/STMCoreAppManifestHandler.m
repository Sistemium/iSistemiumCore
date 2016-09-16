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
#define INDEX_HTML @"index.html"


@interface STMCoreAppManifestHandler()

@property (nonatomic, strong) NSString *localHTMLDirPath;
@property (nonatomic, strong) NSString *updateDirPath;
@property (nonatomic, strong) NSString *eTagFileName;


@end


@implementation STMCoreAppManifestHandler

- (NSString *)localHTMLDirPath {
    
    if (!_localHTMLDirPath) {
    
        _localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                        createIfNotExist:NO
                                     shoudCleanBeforeUse:NO];
        
    }
    return _localHTMLDirPath;
    
}

- (NSString *)updateDirPath {
    
    if (!_updateDirPath) {
        
        _updateDirPath = [self webViewLocalDirForPath:UPDATE_DIR
                                        createIfNotExist:NO
                                     shoudCleanBeforeUse:NO];
        
    }
    return _updateDirPath;
    
}


#pragma mark - directories

- (NSString *)webViewLocalDirForPath:(NSString *)dirPath createIfNotExist:(BOOL)createIfNotExist shoudCleanBeforeUse:(BOOL)cleanBeforeUse {
    
    NSString *ownerName = [self.owner webViewStoryboardParameters][@"name"];
    NSString *ownerTitle = [self.owner webViewStoryboardParameters][@"title"];
    
    NSString *completePath = [@[ownerName, ownerTitle, dirPath] componentsJoinedByString:@"/"];
    
    completePath = [STMFunctions absolutePathForPath:completePath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL isDir;
    
    if ([fm fileExistsAtPath:completePath isDirectory:&isDir]) {
        
        if (isDir) {
            
            return (cleanBeforeUse) ? [self cleanDirAtPath:completePath] : completePath;
            
        } else {
            
            NSString *errorMessage = [NSString stringWithFormat:@"%@ dir path is not a dir", dirPath];
            [self.owner appManifestLoadFailWithErrorText:errorMessage];
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
            
            [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
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
        
        [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
        return nil;
        
    }
    
    return dirPath;
    
}


#pragma mark - localHTML

- (void)startLoadLocalHTML {
    
    [self loadLocalHTML];
    
    NSURL *appManifestURI = [NSURL URLWithString:[self.owner webViewAppManifestURI]];
    
    NSURLRequest *request = [[STMCoreAuthController authController] authenticateRequest:[NSURLRequest requestWithURL:appManifestURI]];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        
        [self handleAppManifestResponse:response
                                   data:data
                                  error:connectionError];
        
    }];

}

- (void)handleAppManifestResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)connectionError {
    
    if (connectionError) {
        
        [self.owner appManifestLoadFailWithErrorText:connectionError.localizedDescription];
        return;
        
    }

    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {

        [self.owner appManifestLoadFailWithErrorText:@"response is not a NSHTTPURLResponse class, can not get eTag"];
        return;

    }
    
    if (data.length == 0) {

        [self.owner appManifestLoadFailWithErrorText:@"response data length is 0"];
        return;

    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    NSString *responseETag = httpResponse.allHeaderFields[@"eTag"];
    self.eTagFileName = [responseETag stringByAppendingString:@".eTag"];

    if ([self shouldUpdateLocalHTML]) {
        
        self.updateDirPath = [self webViewLocalDirForPath:UPDATE_DIR
                                         createIfNotExist:YES
                                      shoudCleanBeforeUse:YES];
        
        if (self.updateDirPath) {
            
            NSString *appManifest = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            if (!appManifest) {
                
                [self.owner appManifestLoadFailWithErrorText:@"can not convert response data to appManifest string"];
                return;
                
            }
            
            [self handleAppManifest:appManifest];
            
        }

    } else {
        [self.owner appManifestLoadFailWithErrorText:@"have no update"];
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

        [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
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
            
            [self.owner appManifestLoadFailWithErrorText:@"something wrong with load file"];
            loadSuccess = NO;
            break;
            
        }
        
    }
    
    if (loadSuccess) {

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *dirObjects = [fm contentsOfDirectoryAtPath:self.updateDirPath error:&error];
        
        if (error) {
            
            [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];

        } else {

            self.localHTMLDirPath = [self webViewLocalDirForPath:LOCAL_HTML_DIR
                                                createIfNotExist:YES
                                             shoudCleanBeforeUse:YES];
            
            for (NSString *dirObject in dirObjects) {
                
                [fm moveItemAtPath:[self.updateDirPath stringByAppendingPathComponent:dirObject]
                            toPath:[self.localHTMLDirPath stringByAppendingPathComponent:dirObject]
                             error:&error];
                
                if (error) {
                    
                    [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
                    break;

                }
                
            }
            
            if (error) {
                
                [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
                
            } else {

                [self saveETagFile];

            }

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
        
        [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
        
    } else {
        
        // should notificate owner about available update
        
    }

}

- (void)loadLocalHTML {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *indexHTMLPath = [self.localHTMLDirPath stringByAppendingPathComponent:INDEX_HTML];

    if ([fm fileExistsAtPath:indexHTMLPath]) {
    
        NSError *error = nil;
        NSString *indexHTMLString = [NSString stringWithContentsOfFile:indexHTMLPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
        
        if (error) {

            [self.owner appManifestLoadFailWithErrorText:error.localizedDescription];
            return;
            
        }
        
        [self.owner loadHTML:indexHTMLString atBaseDir:self.localHTMLDirPath];

    } else {
        [self.owner appManifestLoadFailWithErrorText:@"have no index.html"];
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


@end
