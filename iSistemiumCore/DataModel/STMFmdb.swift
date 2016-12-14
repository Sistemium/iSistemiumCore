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
                let sql_stmt = "CREATE TABLE IF NOT EXISTS STMPrice (ID TEXT  PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, isFantom INTEGER, lts TEXT,  ownerXid TEXT, price REAL, source TEXT, target TEXT, xid TEXT, articleid TEXT REFERENCES STMArticle(id), pricetypeid TEXT REFERENCES STMPriceType(id) ) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                database?.close()
            } else {
                NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            }
        }
    }
    
    func insert(tablename:String,dictionary:Dictionary<String, Any>){
        if (database?.open())! {
            
            var keys:[String] = []
            
            var values:[String] = []

            for (key, value) in dictionary{
                if key == "ts"{
                    keys.append("deviceTs")
                }else{
                    keys.append(key)
                }
                values.append("'\(value)'")
            }
            
            keys.append("lts")
            values.append("'\(Date())'")
            
            let insertSQL = "INSERT INTO \(tablename) (\(keys.joined(separator: ", "))) VALUES (\(values.joined(separator: ", ")))"
            
            let result = database?.executeUpdate(insertSQL,
                                                  withArgumentsIn: nil)
            
            if !result! {
                NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            }
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
    }
}
