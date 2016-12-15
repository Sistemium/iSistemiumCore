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
    
    let databaseName = "database.db"
    
    private var database:FMDatabase!
    
    private override init(){
        let filemgr = FileManager.default
        let dirPaths = filemgr.urls(for: .documentDirectory,
                                    in: .userDomainMask)
        
        let databasePath = dirPaths[0].appendingPathComponent(databaseName).path
        
        database = FMDatabase(path: databasePath as String)
        
        if database == nil {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
        
        if !filemgr.fileExists(atPath: databasePath as String) {
            //STMEntity
            NSLog("Started creating fmdb tables")
            if (database?.open())!{
                database.beginTransaction()
                var sql_stmt = "CREATE TABLE IF NOT EXISTS STMPrice (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, price NUMERIC, articleid TEXT REFERENCES STMArticle(id), pricetypeid TEXT REFERENCES STMPriceType(id) ) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                sql_stmt = "CREATE TABLE IF NOT EXISTS STMArticle (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, barcode TEXT, code TEXT, extraLabel TEXT,factor INTEGER, name TEXT, packageRel INTEGER, pieceVolume NUMERIC, pieceWeight NUMERIC, price NUMERIC, articlegroupid TEXT REFERENCES STMArticleGroup(id)) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                sql_stmt = "CREATE TABLE IF NOT EXISTS STMStock (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, displayVolume TEXT, volume INTEGER, articleid TEXT REFERENCES STMArticle(id)) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                sql_stmt = "CREATE TABLE IF NOT EXISTS STMArticleGroup (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, name TEXT, articlegroupid TEXT REFERENCES STMArticleGroup(id)) "
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
//                sql_stmt = "CREATE TABLE IF NOT EXISTS STMPriceType (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, name TEXT, parentId TEXT REFERENCES STMPriceType(id)) "
//                if !(database?.executeStatements(sql_stmt))! {
//                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
//                }
                sql_stmt = "CREATE TABLE IF NOT EXISTS STMSaleOrderPosition (ID TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, backVolume INTEGER, cost NUMERIC, price NUMERIC, priceDoc NUMERIC, priceOrigin NUMERIC, volume INTEGER, articleid TEXT REFERENCES STMArticle(id), saleorderId TEXT REFERENCES STMSaleOrder(id)) "
                
                if !(database?.executeStatements(sql_stmt))! {
                    NSLog("STMFmdb error: \(database?.lastErrorMessage())")
                }
                database?.commit();
                database?.close()
            } else {
                NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            }
            NSLog("Done creating fmdb tables")
        }
    }
    
    func insert(tablename:String, array:Array<Dictionary<String, Any>>, completionHandler:(_ success:Bool)->Void){
        NSLog("Started inserting \(tablename)")
        if (database?.open())! {
            database.beginTransaction()
            for dictionary in array{
                insert(tablename: tablename, dictionary: dictionary)
            }
            database?.commit();
            database?.close()
            completionHandler(true);
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            completionHandler(false);
        }
        NSLog("Done inserting \(tablename)")
    }

    private func insert(tablename:String, dictionary:Dictionary<String, Any>){
        var keys:[String] = []
        
        var values:[Any] = []
        
        for (key, value) in dictionary{
            switch(key){
            case "ts":
                break
            case "discountPercent":
                break
            case "author":
                break
            case "articleSameId":
                break
            case "productionInfoType":
                break
            default:
                keys.append(key)
                values.append(value)
            }
        }
        
        keys.append("lts")
        values.append("'\(Date())'")
        let v = [String](repeating: "?", count: keys.count)
        let insertSQL = "INSERT OR REPLACE INTO \(tablename) (\(keys.joined(separator: ", "))) VALUES (\(v.joined(separator: ", ")))"
        
        let result = database?.executeUpdate(insertSQL,
                                             withArgumentsIn: values)
        
        if !result! {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
    }
    
    func insert(tablename:String, dictionary:Dictionary<String, Any>, completionHandler:(_ success:Bool)->Void){
        if (database?.open())! {
            insert(tablename: tablename, dictionary: dictionary)
            completionHandler(true);
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
            completionHandler(false);
        }
    }
    
//    func select(tablename:String){
//    SELECT name FROM my_db.sqlite_master WHERE type='table';
//        if (database?.open())! {
//            let sql_stmt = "SELECT * FROM STMPrice CROSS JOIN STMArticle"
//            let rs = try? database.executeQuery(sql_stmt,values:[])
//            while rs!.next() {
//                rs?.resultDictionary().forEach { print("\($0): \($1)") }
//            }
//            database?.close()
//        } else {
//            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
//        }
//    }
    
    func getTableNames()->[String]{
        var rez = [String]()
        if (database?.open())! {
            let sql_stmt = "SELECT name FROM sqlite_master WHERE type='table'"
            let rs = try? database.executeQuery(sql_stmt,values:[])
            while rs!.next() {
                rez.append(rs?.resultDictionary()["name"] as! String)
            }
            database?.close()
        } else {
            NSLog("STMFmdb error: \(database?.lastErrorMessage())")
        }
        return rez
    }
    
    func containstTableWithName(name:String)->Bool{
        return getTableNames().contains(name)
    }
    
}
