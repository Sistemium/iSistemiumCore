//
//  STMModelling.h
//  iSisSales
//
//  Created by Alexander Levin on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

@protocol STMModelling

@required

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName;

@end
