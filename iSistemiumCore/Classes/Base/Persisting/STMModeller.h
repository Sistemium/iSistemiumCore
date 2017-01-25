//
//  STMModeller.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "STMModelling.h"

@interface STMModeller : NSObject <STMModelling>

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;

- (void)initWithModel:(NSManagedObjectModel *)model;

@end
