//
//PictureTests.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 09/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#define PictureDownloadingTestsTimeOut 10

#import "STMPersistingTests.h"
#import "STMCorePicturesController.h"
#import "STMVisitPhoto.h"
#import "iSistemiumCore-Swift.h"
#import "STMCoreSessionManager.h"

@interface STMCorePicturesControllerTests : STMPersistingTests

@end

@implementation STMCorePicturesControllerTests

+ (BOOL)needWaitSession {
    return YES;
}

- (void)testDownloadConnectionForObject {
    
    [STMGarbageCollector searchUnusedImages];
    
    XCTAssertEqual(STMGarbageCollector.unusedImageFiles.count, 0);
    
    [STMCorePicturesController sharedController].persistenceDelegate = self.persister;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    NSString *xid = [STMFunctions uuidString];
    
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Downloading picture"];
    
    STMVisitPhoto *picture = (STMVisitPhoto*) [self.persister newObjectForEntityName:@"STMVisitPhoto"];
    
    [nc addObserver:expectation
           selector:@selector(fulfill)
               name:NOTIFICATION_PICTURE_WAS_DOWNLOADED
             object:picture];
    
    picture.xid = [STMFunctions xidDataFromXidString:xid];
    
    picture.href = @"https://s3-eu-west-1.amazonaws.com/sisdev/STMVisitPhoto/2016/12/28/31d0fd3c5d5c50cca385b5a692df0afb/largeImage.png";
    
    picture.thumbnailHref = @"https://s3-eu-west-1.amazonaws.com/sisdev/STMVisitPhoto/2016/12/28/31d0fd3c5d5c50cca385b5a692df0afb/thumbnail.png";
    
    NSString *expectedImagePath = [xid stringByAppendingString:@".jpg"];
    
    NSString *expectedResizedImagePath = [@"resized_" stringByAppendingString:expectedImagePath];
    
    NSString *expectedThumbnailPath = [@"thumbnail_" stringByAppendingString:expectedImagePath];
    
    NSError *error;
    
    NSDictionary *picDict = [self.persister dictionaryFromManagedObject:picture];
    
    [self.persister mergeSync:@"STMVisitPhoto" attributes:picDict options:nil error:&error];
    
    XCTAssertNil(error);
    
    [STMCorePicturesController downloadConnectionForObject:picture];
    
    [self waitForExpectationsWithTimeout:PictureDownloadingTestsTimeOut handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        [[NSNotificationCenter defaultCenter] removeObserver:expectation];
        
        NSDictionary *rez = [self.persister findSync:@"STMVisitPhoto" identifier:xid options:nil error:&error];
        
        XCTAssertNil(error);
        
        NSLog(@"VisitPhoto: %@", rez);
        
        XCTAssertNil(error);
        
        XCTAssertEqualObjects(rez[@"imagePath"], expectedImagePath);
        
        XCTAssertEqualObjects(rez[@"resizedImagePath"], expectedResizedImagePath);
        
        XCTAssertEqualObjects(rez[@"thumbnailPath"], expectedThumbnailPath);
        
        [self.persister destroySync:@"STMVisitPhoto" identifier:xid options:@{STMPersistingOptionRecordstatuses:@NO} error:&error];
        
        // Need to set real persister because there are real pictures
        [STMCorePicturesController sharedController].persistenceDelegate = [[STMCoreSessionManager.sharedManager currentSession] persistenceDelegate];
        
        [STMGarbageCollector searchUnusedImages];
        
        XCTAssertEqual(STMGarbageCollector.unusedImageFiles.count, 3);
        
        expectation = [self expectationWithDescription:@"removingPictures"];
        
        [STMGarbageCollector removeUnusedImages].then(^(NSError *error){
            XCTAssertEqual(error, nil);
            [expectation fulfill];
        });
        
        [self waitForExpectationsWithTimeout:PictureDownloadingTestsTimeOut handler:^(NSError * _Nullable error) {
            XCTAssertEqual(STMGarbageCollector.unusedImageFiles.count, 0);
        }];
        
    }];
    
}

@end
