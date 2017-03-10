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
#import "STMCoreSessionFiler.h"
#import "STMTestDirectoring.h"

@interface STMCorePicturesControllerTests : STMPersistingTests

@property (nonatomic, strong) id <STMFiling> filing;

@end

@implementation STMCorePicturesControllerTests

- (void)setUp {
    [super setUp];

    id <STMDirectoring> directoring = [[STMTestDirectoring alloc] init];
    
    if (!self.filing) {
        self.filing = [STMCoreSessionFiler coreSessionFilerWithDirectoring:directoring];
    }
}

+ (BOOL)needWaitSession {
    return YES;
}

- (void)testDownloadConnectionForObject {
    
    STMGarbageCollector *garbageCollector = [[STMGarbageCollector alloc] init];
    
    STMCorePicturesController *corePicturesController = [[STMCorePicturesController alloc] init];
    
    garbageCollector.filing = self.filing;
    
    corePicturesController.persistenceDelegate = self.persister;
    
    corePicturesController.filing = self.filing;
    
    XCTAssertEqual(garbageCollector.unusedImageFiles.count, 0);
    
    NSString *xid = [STMFunctions uuidString];
    
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Downloading picture"];
    
    NSString* entityName = @"STMVisitPhoto";
    
    NSDictionary *picture = @{@"id":xid,
                              @"href":@"https://s3-eu-west-1.amazonaws.com/sisdev/STMVisitPhoto/2016/12/28/31d0fd3c5d5c50cca385b5a692df0afb/largeImage.png",
                              @"thumbnailHref":@"https://s3-eu-west-1.amazonaws.com/sisdev/STMVisitPhoto/2016/12/28/31d0fd3c5d5c50cca385b5a692df0afb/thumbnail.png",
                              };
    
    NSString *expectedImagePath = [entityName stringByAppendingPathComponent:[xid stringByAppendingString:@".jpg"]];
    
    NSString *expectedResizedImagePath = [entityName stringByAppendingPathComponent:[@"resized_" stringByAppendingString:[xid stringByAppendingString:@".jpg"]]];
    
    NSString *expectedThumbnailPath = [entityName stringByAppendingPathComponent:[@"thumbnail_" stringByAppendingString:[xid stringByAppendingString:@".jpg"]]];
    
    NSError *error;

    picture = [self.persister mergeSync:entityName attributes:picture options:nil error:&error];
    
    XCTAssertNil(error);
    
    [corePicturesController downloadImagesEntityName:entityName attributes:picture].then(^(NSDictionary *picture){
        XCTAssertNotNil(picture);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:PictureDownloadingTestsTimeOut handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        [[NSNotificationCenter defaultCenter] removeObserver:expectation];
        
        NSDictionary *rez = [self.persister findSync:entityName identifier:xid options:nil error:&error];
        
        XCTAssertNil(error);
        
        NSLog(@"VisitPhoto: %@", rez);
        
        XCTAssertNil(error);
        
        XCTAssertEqualObjects(rez[@"imagePath"], expectedImagePath);
        
        XCTAssertEqualObjects(rez[@"resizedImagePath"], expectedResizedImagePath);
        
        XCTAssertEqualObjects(rez[@"thumbnailPath"], expectedThumbnailPath);
        
        [self.persister destroySync:entityName identifier:xid options:@{STMPersistingOptionRecordstatuses:@NO} error:&error];
        
        // Need to set real persister because there are real pictures
        corePicturesController.persistenceDelegate = [[STMCoreSessionManager.sharedManager currentSession] persistenceDelegate];
        
        [garbageCollector searchUnusedImages];
        
        XCTAssertEqual(garbageCollector.unusedImageFiles.count, 3);
        
        expectation = [self expectationWithDescription:@"removingPictures"];
        
        [garbageCollector removeUnusedImages].then(^(NSError *error){
            XCTAssertEqual(error, nil);
            [expectation fulfill];
        });
        
        [self waitForExpectationsWithTimeout:PictureDownloadingTestsTimeOut handler:^(NSError * _Nullable error) {
            XCTAssertEqual(STMGarbageCollector.sharedInstance.unusedImageFiles.count, 0);
        }];
        
    }];
    
}

@end
