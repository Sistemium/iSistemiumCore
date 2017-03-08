//
//  STMDocument.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "STMFiling.h"


@interface STMDocument : UIManagedDocument

@property (nonatomic, strong, readonly) NSManagedObjectModel *myManagedObjectModel;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic) BOOL isSaving;

+ (STMDocument *)documentWithUID:(NSString *)uid
                          iSisDB:(NSString *)iSisDB
                          filing:(id <STMFiling>)filing
                   dataModelName:(NSString *)dataModelName;

+ (void)openDocument:(STMDocument *)document;

- (void)saveDocument:(void (^)(BOOL success))completionHandler;


@end
