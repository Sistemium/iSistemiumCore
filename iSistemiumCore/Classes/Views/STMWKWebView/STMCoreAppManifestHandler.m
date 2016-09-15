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

@interface STMCoreAppManifestHandler()

@property (nonatomic, strong) NSString *localHTMLDirPath;
@property (nonatomic, strong) NSString *updateDirPath;
@property (nonatomic, strong) NSString *responseETag;


@end


@implementation STMCoreAppManifestHandler


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

- (void)loadLocalHTML {
    
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
    
    self.responseETag = httpResponse.allHeaderFields[@"eTag"];
    
    if ([self shouldUpdateLocalHTMLWithETag:self.responseETag]) {
    
        self.updateDirPath = [self webViewLocalDirForPath:@"update"
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

    }
    
}

- (BOOL)shouldUpdateLocalHTMLWithETag:(NSString *)eTag {
    
    self.localHTMLDirPath = [self webViewLocalDirForPath:@"localHTML"
                                        createIfNotExist:NO
                                     shoudCleanBeforeUse:NO];

    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *error;
    NSArray *dirFiles = [fm contentsOfDirectoryAtPath:self.localHTMLDirPath error:&error];
    
    if (!error) {
        
        NSArray *currentETagFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '%@.eTag'", eTag]];
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
    
    for (NSString *filePath in filePaths) {
        
        if (![self loadAppManifestFile:filePath]) {
            
            [self.owner appManifestLoadFailWithErrorText:@"something wrong with load file"];
            break;
            
        }
        
    }
    
    NSLog(@"");
    
}

- (BOOL)loadAppManifestFile:(NSString *)filePath {
    
    NSURL *baseURL = [NSURL URLWithString:[self.owner webViewAppManifestURI]].URLByDeletingLastPathComponent;
    NSURL *fileURL = [baseURL URLByAppendingPathComponent:filePath];
    
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    if (self.updateDirPath) {
    
        NSString *localFilePath = [self.updateDirPath stringByAppendingPathComponent:filePath];
        
        NSError *error = nil;
        
        [fileData writeToFile:localFilePath
                      options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                        error:&error];
        
        NSLog(@"%@", error.localizedDescription);
        
        return YES;

    } else {
        return NO;
    }
    
    //        NSString *indexHTMLPath = [STMFunctions absolutePathForPath:@"localHTML/index.html"];
    //
    //        NSString *indexHTMLString = [NSString stringWithContentsOfFile:indexHTMLPath
    //                                                              encoding:NSUTF8StringEncoding
    //                                                                 error:nil];
    //
    //        NSString *indexHTMLBasePath = [STMFunctions absolutePathForPath:@"localHTML"];
    //
    //        [self.webView loadHTMLString:indexHTMLString baseURL:[NSURL fileURLWithPath:indexHTMLBasePath]];

}


@end
