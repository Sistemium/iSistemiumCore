//
//  STMScriptMessageController.swift
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import Foundation
import WebKit


class STMScriptMessageController: NSObject {
    
    @available(iOS 8.0, *)

    class func predicateForScriptMessage(scriptMessage: WKScriptMessage, error: NSErrorPointer) -> NSPredicate? {
    
        guard let body: Dictionary = scriptMessage.body as? [String: AnyObject] else {
            errorWithMessage(error, errorMessage: "message body is not a Dictionary")
            return nil
        }
        
        guard var entityName: String = body["entity"] as? String else {
            errorWithMessage(error, errorMessage: "message body have no entity name")
            return nil
        }
        
        entityName = "STM" + entityName
        
        guard STMCoreObjectsController.localDataModelEntityNames().contains(entityName) else {
            errorWithMessage(error, errorMessage: "local data model have no entity with name \(entityName)")
            return nil
        }
        
        let name: String = scriptMessage.name

        switch name {
            
            case STMSwiftConstants.ScriptMessageNames.WK_SCRIPT_MESSAGE_FIND:
                
                guard let xid: NSData? = STMFunctions.xidDataFromXidString(body["id"] as? String) else {
                    errorWithMessage(error, errorMessage: "where is no xid in \(STMSwiftConstants.ScriptMessageNames.WK_SCRIPT_MESSAGE_FIND) script message")
                    return nil
                }
                
                return predicateForFilters(entityName, filter: ["xid": xid!], whereFilter: nil, error: error)
            
            case STMSwiftConstants.ScriptMessageNames.WK_SCRIPT_MESSAGE_FIND_ALL:
                
                guard let filter: [String: AnyObject]? = body["filter"] as? [String: AnyObject] else {
                    print("filter section malformed")
                    break
                }
                
                guard let whereFilter: [String: [String: AnyObject]]? = body["where"] as? [String: [String: AnyObject]] else {
                    print("whereFilter section malformed")
                    break
                }
                
                return predicateForFilters(entityName, filter: filter, whereFilter: whereFilter, error: error)
                
            default: break
            
        }

        errorWithMessage(error, errorMessage: "unknown script message with name \(name)")
        return nil
        
    }

    class func predicateForFilters(entityName: String, filter: [String: AnyObject]?, whereFilter: [String: [String: AnyObject]]?, error: NSErrorPointer) -> NSPredicate {
        
        var filterDictionary: [String: [String: AnyObject]] = (whereFilter != nil) ? whereFilter! : [String: [String: AnyObject]]();
        
        if (filter != nil) {
            for key in filter!.keys {
                filterDictionary[key] = ["==": filter![key]!]
            }
        }
        
        let subpredicates: [NSPredicate] = subpredicatesForFilterDictionaryWithEntityName(entityName, filterDictionary: filterDictionary)
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        
    }

    class func subpredicatesForFilterDictionaryWithEntityName(entityName: String, filterDictionary: [String: [String: AnyObject]]) -> [NSPredicate] {
        
        let entityDescription: STMEntityDescription = STMEntityDescription.entityForName(entityName, inManagedObjectContext: currentContext())
        
        let properties: [String : NSPropertyDescription] = entityDescription.propertiesByName
        let attributes: [String : NSAttributeDescription] = entityDescription.attributesByName
        let relationships: [String : NSRelationshipDescription] = entityDescription.relationshipsByName

        var subpredicates: [NSPredicate] = []
        
        for key in filterDictionary.keys {
            
            self.checkFilterKeyForSubpredicates(&subpredicates,
                                                filterDictionary: filterDictionary,
                                                key: key,
                                                relationships: relationships,
                                                attributes: attributes,
                                                properties: properties,
                                                entityName: entityName)

        }
        
        return subpredicates
        
    }
    
    class func checkFilterKeyForSubpredicates(inout subpredicates: [NSPredicate], filterDictionary: [String: [String: AnyObject]], key: String, relationships: [String : NSRelationshipDescription], attributes: [String : NSAttributeDescription], properties: [String : NSPropertyDescription], entityName: String) {
        
        var localKey: String = key
        
        if key == "id" { localKey = "xid" }
        if key == "ts" { localKey = "deviceTs" }
        
        let relKey: String = "Id"
        
        if key.hasSuffix(relKey) {
            
            let substringIndex = key.endIndex.advancedBy(-relKey.characters.count);
            
            if relationships.keys.contains(key.substringToIndex(substringIndex)) {
                localKey = key.substringToIndex(substringIndex)
            }
            
        }
        
        guard properties.keys.contains(localKey) else {
            print("\(entityName) have not property \(localKey)")
            return
        }
        
        let isAttribute: Bool = attributes.keys.contains(localKey)
        let isRelationship: Bool = relationships.keys.contains(localKey)
        
        guard isAttribute == true || isRelationship == true else {
            print("unknown kind of property '\(localKey)'")
            return
        }
        
        let arguments: [String: AnyObject] = filterDictionary[key]!
        
        let comparisonOperators: [String] = ["==", "!=", ">=", "<=", ">", "<"]
        
        self.fillSupredicatesForParams(&subpredicates,
                                       comparisonOperators: comparisonOperators,
                                       arguments: arguments,
                                       localKey: localKey,
                                       isAttribute: isAttribute,
                                       isRelationship: isRelationship,
                                       entityName: entityName,
                                       attributes: attributes,
                                       relationships: relationships)

    }
    
    class func fillSupredicatesForParams(inout subpredicates: [NSPredicate], comparisonOperators: [String], arguments: [String: AnyObject], localKey: String, isAttribute: Bool, isRelationship: Bool, entityName: String, attributes: [String : NSAttributeDescription], relationships: [String : NSRelationshipDescription]) {
        
        for compOp in arguments.keys {

            var subpredicate: NSPredicate
            
            let (subpredicateString, argumentArray) = self.subpredicateStringForParams(compOp,
                                                                                       comparisonOperators: comparisonOperators,
                                                                                       arguments: arguments,
                                                                                       localKey: localKey,
                                                                                       isAttribute: isAttribute,
                                                                                       isRelationship: isRelationship,
                                                                                       entityName: entityName,
                                                                                       attributes: attributes,
                                                                                       relationships: relationships)

            if subpredicateString != nil {
                
                subpredicate = NSPredicate(format: subpredicateString!, argumentArray: argumentArray)
                subpredicates.append(subpredicate)

            }

        }

    }

    class  func subpredicateStringForParams(compOp: String, comparisonOperators: [String], arguments: [String: AnyObject], localKey: String, isAttribute: Bool, isRelationship: Bool, entityName: String, attributes: [String : NSAttributeDescription], relationships: [String : NSRelationshipDescription]) -> (subpredicateString: String?, argumentArray: [AnyObject]?) {
        
        guard comparisonOperators.contains(compOp) else {
            print("comparison operator should be '==', '!=', '>=', '<=', '>' or '<', not '\(compOp)'")
            return (nil, nil)
        }
        
        //                guard var value: AnyObject? = arguments[compOp] else {
        //                    print("have no value for comparison operator '\(compOp)'")
        //                    continue
        //                }
        
        var value: AnyObject? = arguments[compOp]
        
        if localKey.lowercaseString.hasSuffix("uuid") || localKey.lowercaseString.hasSuffix("xid") || isRelationship {
            
            guard value is String else {
                print("value is not a String, but it should be to get xid or uuid value")
                return (nil, nil)
            }
            
            value = value?.stringByReplacingOccurrencesOfString("-", withString: "")
            
        }
        
        if isAttribute {
            
            guard let className: String = attributes[localKey]!.attributeValueClassName else {
                print("\(entityName) have no class type for key \(localKey)")
                return (nil, nil)
            }
            
            value = normalizeValue(value, className: className)
            
        } else if isRelationship {
            
            guard ((relationships[localKey]?.toMany) == false) else {
                print("relationship \(localKey) is toMany")
                return (nil, nil)
            }
            
            guard let className: String = relationships[localKey]!.destinationEntity?.name else {
                print("\(entityName) have no class type for key \(localKey)")
                return (nil, nil)
            }
            
            value = relationshipObjectForValue(value, className: className)
            
        }
        
        var subpredicateString: String
        var argumentArray: [AnyObject]?
        
        if value != nil {
            
            subpredicateString = "\(localKey) \(compOp) %@"
            argumentArray = [value!]
            
        } else {
            
            subpredicateString = "\(localKey) \(compOp) nil"
            argumentArray = nil
            
        }

        return (subpredicateString, argumentArray)

    }
    
    class func normalizeValue(value: AnyObject?, className: String) -> AnyObject? {
        
        var value = value
        
        guard value != nil else {
            return nil
        }
        
        if value is NSNumber { value = value!.stringValue }
        
        switch className {
            
            case NSStringFromClass(NSNumber)    :   return NSNumberFormatter().numberFromString(value as! String)!
                
            case NSStringFromClass(NSDate)      :   return STMFunctions.dateFormatter().dateFromString(value as! String)!
                
            case NSStringFromClass(NSData)      :   return STMFunctions.dataFromString(value as! String)
                
            default                             :   return value
            
        }
        
    }
    
    class func relationshipObjectForValue(value: AnyObject?, className: String) -> AnyObject? {
        
        var value = value
        
        guard value is String else {
            print("relationship value is not a String, can not get xid")
            return nil
        }
        
        value = STMCoreObjectsController.objectForXid(STMFunctions.dataFromString(value as! String), entityName: className)
        
        return value

    }

    class func currentContext() -> NSManagedObjectContext {
        
        return STMCoreSessionManager.sharedManager().currentSession.document.managedObjectContext
        
    }
    
    class func errorWithMessage(error: NSErrorPointer, errorMessage: String) {
        
        let bundleId: String? = NSBundle.mainBundle().bundleIdentifier
        
        if (bundleId != nil && error != nil) {
         
            error.memory = NSError(domain: bundleId!, code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            
        }
        
    }
    
}
