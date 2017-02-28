//
//  STMFiling.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 27/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDirectoring <NSObject>

@optional

- (instancetype)initWithOrg:(NSString *)org userId:(NSString *)uid;
- (NSString *)userDocuments;
- (NSString *)sharedDocuments;
- (NSBundle *)bundle;


@end


@protocol STMFiling <NSObject>

@optional

@property (nonatomic, weak) id <STMDirectoring> directoring;
@property (nonatomic, weak) NSFileManager *fileManager;

- (NSString *)persistencePath:(NSString *)folderName;
- (NSString *)picturesPath:(NSString *)folderName;
- (NSString *)webViewsPath:(NSString *)folderName;
- (NSString *)persistencePath:(NSString *)folderName;

- (BOOL)copyFile:(NSString *)filePath toPath:(NSString *)newPath;

- (NSString *)bundledModelFile:(NSString *)name;


@end
