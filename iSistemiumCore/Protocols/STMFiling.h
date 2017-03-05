//
//  STMFiling.h
//  iSistemiumCore
//
//  Created by Maxim Grigoriev on 27/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDirectoring

@property (readonly) NSString *userDocuments;
@property (readonly) NSString *sharedDocuments;
@property (readonly) NSBundle *bundle;

@end


@protocol STMFiling

- (NSString *)basePath:(NSString *)basePath
              withPath:(NSString *)path;

- (NSString *)persistenceBasePath;
- (NSString *)picturesBasePath;
- (NSString *)webViewsBasePath;

- (NSString *)persistencePath:(NSString *)folderName;
- (NSString *)picturesPath:(NSString *)folderName;
- (NSString *)webViewsPath:(NSString *)folderName;

- (NSString *)temporaryDirectoryPathWithPath:(NSString *)path;

- (BOOL)copyItemAtPath:(NSString *)sourcePath
                toPath:(NSString *)destinationPath
                 error:(NSError **)error;

- (BOOL)removeItemAtPath:(NSString *)path
                   error:(NSError **)error;

- (NSString *)bundledModelFile:(NSString *)name;
- (NSString *)userModelFile:(NSString *)name;

- (BOOL)enumerateDirAtPath:(NSString *)dirPath
                 withBlock:(BOOL (^)(NSString *path, NSError **error))enumDirBlock;

@end
