//
//  STMEntityDescription.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface STMEntityDescription : NSEntityDescription

+ (STMEntityDescription *)entityForName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context;


@end
