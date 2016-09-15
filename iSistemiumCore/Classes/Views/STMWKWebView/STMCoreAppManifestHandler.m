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
        
        [owner appManifestLoadFailWithError:connectionError];
        return;
        
    }

    NSLog(response.description);
    NSString *appManifest = [NSString stringWithUTF8String:data.bytes];
    
    NSLog(appManifest);

}


@end
