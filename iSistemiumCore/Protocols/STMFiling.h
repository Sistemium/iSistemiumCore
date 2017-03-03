//
//  STMFiling.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 27/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDirectoring <NSObject>

- (instancetype)initWithOrg:(NSString *)org
                     userId:(NSString *)uid;

- (NSString *)userDocuments;
- (NSString *)sharedDocuments;
- (NSBundle *)bundle;


@end


@protocol STMFiling <NSObject>

@property (nonatomic, weak) id <STMDirectoring> directoring;
@property (nonatomic, weak) NSFileManager *fileManager;

- (NSString *)persistencePath:(NSString *)folderName;
- (NSString *)picturesPath:(NSString *)folderName;
- (NSString *)webViewsPath:(NSString *)folderName;

- (BOOL)copyItemAtPath:(NSString *)sourcePath
                toPath:(NSString *)destinationPath
                 error:(NSError **)error;

- (BOOL)removeItemAtPath:(NSString *)path
                   error:(NSError **)error;

- (NSString *)bundledModelFile:(NSString *)name;
- (NSString *)userModelFile:(NSString *)name;


@end
