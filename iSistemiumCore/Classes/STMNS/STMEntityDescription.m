//
//  STMEntityDescription.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMEntityDescription.h"
#import "STMSessionManager.h"

#import <Crashlytics/Crashlytics.h>


@implementation STMEntityDescription

+ (id)insertNewObjectForEntityForName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context {
    
    NSString *eName = [NSString stringWithFormat:@"%@", entityName];
    
    return [super insertNewObjectForEntityForName:eName inManagedObjectContext:context];
    
}

+ (STMEntityDescription *)entityForName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context {
    
    if (context) {
        
        NSString *eName = [NSString stringWithFormat:@"%@", entityName];
        
        return (STMEntityDescription *)[super entityForName:eName inManagedObjectContext:context];
        
    } else {
        
        STMDocument *document = [[[STMSessionManager sharedManager] currentSession] document];
        
        CLS_LOG(@"entityForName method — context is nil");
        CLS_LOG(@"document %@", document);
        CLS_LOG(@"documentState %lu", (unsigned long)document.documentState);
        CLS_LOG(@"managedObjectContext %@", document.managedObjectContext);
        CLS_LOG(@"parentContext %@", document.managedObjectContext.parentContext);

        return nil;
        
    }

}

@end
