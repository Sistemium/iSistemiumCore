//
//  STMPersisting.h
//  iSisSales
//
//  Created by Alexander Levin on 29/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#ifndef STMPersisting_h
#define STMPersisting_h

typedef NS_ENUM(NSInteger, STMStorageType) {
    STMStorageTypeFMDB,
    STMStorageTypeCoreData,
    STMStorageTypeAbstract,
    STMStorageTypeNone
};

#define STMPersistingOptionRecordstatuses @"createRecordStatuses"
#define STMPersistingOptionFantoms @"fantoms"
#define STMPersistingOptionLts @"lts"
#define STMPersistingOptionReturnSaved @"returnSaved"
#define STMPersistingOptionForceStorage @"forceStorage"
#define STMPersistingOptionPageSize @"pageSize"

#define STMPersistingOptionForceStorageCoreData STMPersistingOptionForceStorage:@(STMStorageTypeCoreData)

#endif /* STMPersisting_h */
