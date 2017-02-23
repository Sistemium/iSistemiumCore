//
//  STMOperation.h
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STMOperationQueue;

@interface STMOperation : NSOperation

@property (nonatomic,weak) STMOperationQueue *queue;
@property (nonatomic,strong) NSDate *startedAt;
@property (nonatomic) NSTimeInterval finishedIn;
@property (readonly) NSString *printableFinishedIn;

+ (instancetype)asynchronousOperation;

- (void)finish;



@end
