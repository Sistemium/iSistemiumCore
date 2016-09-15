//
//  STMCoreAppManifestHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 15/09/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreAppManifestHandler.h"

@implementation STMCoreAppManifestHandler

+ (void)loadLocalHTMLWithOwner:(STMCoreWKWebViewVC *)owner {
    
    NSURL *appManifestURI = [NSURL URLWithString:[owner webViewAppManifestURI]];

    NSURLRequest *request = [[STMCoreAuthController authController] authenticateRequest:[NSURLRequest requestWithURL:appManifestURI]];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                               
                               [self handleAppManifestResponse:response
                                                          data:data
                                                         error:connectionError
                                                         owner:owner];
                               
                           }];
    
    //    NSError *error = nil;
    //    NSString *appManifest = [NSString stringWithContentsOfURL:appManifestURL encoding:NSUTF8StringEncoding error:&error];
    //
    //    NSLog(appManifest);
    //
    //    NSMutableArray *appManifestComponents = [appManifest componentsSeparatedByString:@"\n"].mutableCopy;
    //
    //    NSURL *localHTMLZipUrl = [NSURL URLWithString:@"http://maxbook.local/~grimax/test/iSisSalesWeb.zip"];
    //    NSData *localHTMLZipData = [NSData dataWithContentsOfURL:localHTMLZipUrl];
    //
    //    NSString *zipPath = [STMFunctions absolutePathForPath:@"iSisSalesWeb.zip"];
    //
    //    if ([localHTMLZipData writeToFile:zipPath
    //                              options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
    //                                error:nil]) {
    //
    //        NSString *destPath = [STMFunctions absolutePathForPath:@"/localHTML"];
    //
    //        if (![[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
    //
    //            [[NSFileManager defaultManager] createDirectoryAtPath:destPath
    //                                      withIntermediateDirectories:NO
    //                                                       attributes:nil
    //                                                            error:nil];
    //
    //            //            [SSZipArchive unzipFileAtPath:zipPath toDestination:destPath];
    //
    //        }
    //
    //    } else {
    //
    //    }
    
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

+ (void)handleAppManifestResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)connectionError owner:(STMCoreWKWebViewVC *)owner {
    
    if (connectionError) {
        
        [owner appManifestLoadFailWithErrorText:connectionError.localizedDescription];
        return;
        
    }

    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {

        [owner appManifestLoadFailWithErrorText:@"response is not a NSHTTPURLResponse class, can not get eTag"];
        return;

    }
    
    if (data.length == 0) {

        [owner appManifestLoadFailWithErrorText:@"response data length is 0"];
        return;

    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    NSString *eTag = httpResponse.allHeaderFields[@"eTag"];
    NSString *appManifest = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if (!appManifest) {
        
        [owner appManifestLoadFailWithErrorText:@"can not convert response data to appManifest string"];
        return;
        
    }
    
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
        
        if (![self loadAppManifestFile:filePath owner:owner]) {
            
            [owner appManifestLoadFailWithErrorText:@"something wrong with load file"];
            break;
            
        }
        
    }
    
    NSLog(@"");
    
}

+ (BOOL)loadAppManifestFile:(NSString *)filePath owner:(STMCoreWKWebViewVC *)owner {
    
    NSURL *baseURL = [NSURL URLWithString:[owner webViewAppManifestURI]].URLByDeletingLastPathComponent;
    NSURL *fileURL = [baseURL URLByAppendingPathComponent:filePath];
    
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    NSString *updateDirPath = [self updateDirPathForOwner:owner];
    
    if (updateDirPath) {
    
        NSString *localFilePath = [STMFunctions absolutePathForPath:filePath];
        
        NSError *error = nil;
        
        [fileData writeToFile:localFilePath
                      options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                        error:&error];
        
        NSLog(@"%@", error.localizedDescription);
        
        return YES;

    } else {
        return NO;
    }
    
}

+ (NSString *)updateDirPathForOwner:(STMCoreWKWebViewVC *)owner {
    
    NSString *ownerName = [owner webViewStoryboardParameters][@"name"];
    NSString *ownerTitle = [owner webViewStoryboardParameters][@"title"];
    NSString *updatePath = @"update";
    
    NSString *completePath = [@[ownerName, ownerTitle, updatePath] componentsJoinedByString:@"/"];
    
    completePath = [STMFunctions absolutePathForPath:completePath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL isDir;
    
    if ([fm fileExistsAtPath:completePath isDirectory:&isDir]) {
        
        if (isDir) {
            
            return completePath;
            
        } else {
            
            [owner appManifestLoadFailWithErrorText:@"update dir path is not dir"];
            return nil;

        }
        
    } else {
        
        NSError *error = nil;
        
        [fm createDirectoryAtPath:completePath withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error) {
            
            [owner appManifestLoadFailWithErrorText:error.localizedDescription];
            return nil;
            
        }
        
        return completePath;
        
    }
    
    
    
}


@end
