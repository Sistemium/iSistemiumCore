//
//  STMDefantomizing.h
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^STMDefantomizingArrayResultCallback)(NSArray <NSDictionary *> *fantomsArray);

@protocol STMDefantomizing <NSObject>

- (void)findFantomsWithCompletionHandler:(STMDefantomizingArrayResultCallback)completionHandler;

- (void)defantomizeErrorWithObject:(NSDictionary *)fantomDic
                      deleteObject:(BOOL)deleteObject;

- (void)defantomizingFinished;

@end
