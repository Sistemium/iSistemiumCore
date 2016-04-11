//
//  STMFetchRequest.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 11/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface STMFetchRequest : NSFetchRequest

+ (STMFetchRequest *)fetchRequestWithEntityName:(NSString *)entityName;


@end
