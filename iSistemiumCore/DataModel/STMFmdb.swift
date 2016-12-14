//
//  STMFmdb.swift
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import FMDB

@objc
class STMFmdb:NSObject{
    
    static let sharedInstance = STMFmdb()
    
    private var database:FMDatabase!
    
    private override init(){
        let filemgr = FileManager.default
        let dirPaths = filemgr.urls(for: .documentDirectory,
                                    in: .userDomainMask)
        
        let databasePath = dirPaths[0].appendingPathComponent("database.db").path
        
        database = FMDatabase(path: databasePath as String)
        
        if database == nil {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
        
        if !filemgr.fileExists(atPath: databasePath as String) {
            
            if (database?.open())!{
                let sql_stmt = "CREATE TABLE IF NOT EXISTS STMPrice (ID INTEGER PRIMARY KEY AUTOINCREMENT, commentText TEXT, deviceCts TEXT, deviceTs TEXT, isFantom INTEGER, lts TEXT,  ownerXid TEXT, price NUMERIC, source TEXT, target TEXT, xid TEXT UNIQUE, articleid TEXT REFERENCES STMArticle(id), pricetypeid TEXT REFERENCES STMPriceType(id) ) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                database?.close()
            } else {
                NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            }
        }
    }
    
    func insert(tablename:String, array:Array<Dictionary<String, Any>>, completionHandler:(_ success:Bool)->Void){
        if (database?.open())! {
            database.beginTransaction()
            for dictionary in array{
                var keys:[String] = []
                
                var values:[String] = []
                
                for (key, value) in dictionary{
                    switch(key){
                        case "ts":
                        keys.append("deviceTs")
                    case "id":
                        keys.append("xid")
                    default:
                        keys.append(key)
                    }
                    values.append("'\(value)'")
                }
                
                keys.append("lts")
                values.append("'\(Date())'")
                
                let insertSQL = "INSERT OR REPLACE INTO \(tablename) (\(keys.joined(separator: ", "))) VALUES (\(values.joined(separator: ", ")))"
                
                let result = database?.executeUpdate(insertSQL,
                                                     withArgumentsIn: nil)
                
                if !result! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
            }
            database?.commit();
            database?.close()
            completionHandler(true);
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            completionHandler(false);
        }
    }
    
    func select(tablename:String){
        if (database?.open())! {
            let sql_stmt = "SELECT * FROM STMPrice WHERE xid = '86168941-ab33-11e6-8000-8c84fdbebcad'"
            let rs = try? database.executeQuery(sql_stmt,values:[])
            while rs!.next() {
                rs?.resultDictionary().forEach { print("\($0): \($1)") }
            }
            database?.close()
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
    }
}
