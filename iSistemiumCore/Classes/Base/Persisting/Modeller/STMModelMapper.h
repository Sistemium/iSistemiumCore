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

- (instancetype)initWithSourceModel:(NSManagedObjectModel *)sourceModel
                   destinationModel:(NSManagedObjectModel *)destinationModel
                              error:(NSError **)error;


@end
