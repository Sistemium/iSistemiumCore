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
    STMStorageTypeNone,
    STMStorageTypeInMemory
};

#define STMPersistingKeyVersion @"deviceTs"

#define STMPersistingOptions NSDictionary *

#define STMPersistingOptionRecordstatuses @"createRecordStatuses"
#define STMPersistingOptionFantoms @"fantoms"
#define STMPersistingOptionLts @"lts"
#define STMPersistingOptionReturnSaved @"returnSaved"
#define STMPersistingOptionForceStorage @"forceStorage"
#define STMPersistingOptionPageSize @"pageSize"
#define STMPersistingOptionOffset @"offset"
#define STMPersistingOptionOrder @"sortBy"
#define STMPersistingOptionOrderDirection @"direction"
#define STMPersistingOptionFieldstoUpdate @"fieldsToUpdate"
#define STMPersistingOptionSetTs @"setTs"

#define STMPersistingOptionOrderDirectionDescValue @"DESC"
#define STMPersistingOptionOrderDirectionAscValue @"ASC"

#define STMPersistingOptionOrderDirectionDesc \
STMPersistingOptionOrderDirection:STMPersistingOptionOrderDirectionDescValue

#define STMPersistingOptionOrderDirectionAsc \
STMPersistingOptionOrderDirection:STMPersistingOptionOrderDirectionAscValue

#define STMPersistingOptionForceStorageCoreData STMPersistingOptionForceStorage:@(STMStorageTypeCoreData)
#define STMPersistingOptionForceStorageFMDB STMPersistingOptionForceStorage:@(STMStorageTypeFMDB)

#endif /* STMPersisting_h */
