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
    STMStorageTypeFMDB = 0,
    STMStorageTypeCoreData = 1,
    STMStorageTypeAbstract = 2,
    STMStorageTypeNone = 3,
    STMStorageTypeInMemory = 4
};

#define STMPersistingKeyPrimary @"id"
#define STMPersistingKeyVersion @"deviceTs"
#define STMPersistingKeyCreationTimestamp @"deviceCts"
#define STMPersistingKeyPhantom @"isFantom"

#define STMPersistingRelationshipSuffix @"Id"

#define STMPersistingOptions NSDictionary *

#define STMPersistingOptionRecordstatuses @"createRecordStatuses"
#define STMPersistingOptionPhantoms @"fantoms"
#define STMPersistingOptionLts @"lts"
#define STMPersistingOptionLtsNow STMPersistingOptionLts:[STMFunctions stringFromNow]
#define STMPersistingOptionReturnSaved @"returnSaved"
#define STMPersistingOptionForceStorage @"forceStorage"
#define STMPersistingOptionPageSize @"pageSize"
#define STMPersistingOptionStartPage @"startPage"
#define STMPersistingOptionGroupBy @"groupBy"
#define STMPersistingOptionWhere @"where"
#define STMPersistingOptionOffset @"offset"
#define STMPersistingOptionOrder @"sortBy"
#define STMPersistingOptionOrderDirection @"direction"
#define STMPersistingOptionFieldsToUpdate @"fieldsToUpdate"
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
