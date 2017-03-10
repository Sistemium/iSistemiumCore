//
//  STMModelMapper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMModelMapping.h"


@interface STMModelMapper : NSObject <STMModelMapping>

- (instancetype)initWithModelName:(NSString *)modelName
                           filing:(id <STMFiling>)filing
                            error:(NSError **)error;

- (instancetype)initWithSourceModelName:(NSString *)sourceModelName
                   destinationModelName:(NSString *)destinationModelName
                                 filing:(id <STMFiling>)filing
                                  error:(NSError **)error;


@end
