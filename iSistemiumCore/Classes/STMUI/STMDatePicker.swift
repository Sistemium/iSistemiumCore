//
//  STMDatePicker.swift
//  test
//
//  Created by Maxim Grigoriev on 08/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

import UIKit

class STMDatePicker: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var yearRangeLength: Int = 20
    var numberOfDays: Int = 31

    override init (frame : CGRect) {
        
        super.init(frame : frame)
        self.customInit()
        
    }
    
    convenience init () {
        self.init(frame:CGRect.zero)
    }

    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        self.customInit()
        
//        fatalError("init(coder:) has not been implemented")
        
    }
    
    func customInit() {

        self.delegate = self
        self.dataSource = self

        self.setPickerToCurrentDate(false)
        
    }
    
    func setPickerToCurrentDate(_ animated: Bool) {
        
        self.selectRow(self.currentDay() - 1, inComponent: 0, animated: animated)
        self.selectRow(self.currentMonth() - 1, inComponent: 1, animated: animated)
        self.selectRow(yearRangeLength - 1, inComponent: 2, animated: animated)

    }
    
    
//MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 3
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        switch component {
            
        case 0:
            return numberOfDays
        case 1:
            return 12
        case 2:
            return yearRangeLength

        default:
            return 0
        }
        
    }
    
    
//MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        var stringToShow: String
        
        if component == 2 {
            
            stringToShow = String(self.currentYear() - yearRangeLength + row + 1)
            
        } else {
            
            let numberFormatter: NumberFormatter = NumberFormatter.init()
            numberFormatter.minimumIntegerDigits = 2

            stringToShow = numberFormatter.string(from: row + 1)!
            
        }
        
        return stringToShow
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        var dateComponents = DateComponents()
        dateComponents.day = pickerView.selectedRow(inComponent: 0) + 1
        dateComponents.month = pickerView.selectedRow(inComponent: 1) + 1
        dateComponents.year = self.currentYear() - yearRangeLength + pickerView.selectedRow(inComponent: 2) + 1
        
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!

        if date.compare(Date()) == ComparisonResult.orderedAscending {
        
            if component > 0 {
                
                let month: Int = pickerView.selectedRow(inComponent: 1) + 1
                let year: Int = self.currentYear() - yearRangeLength + pickerView.selectedRow(inComponent: 2) + 1
                
                numberOfDays = numberOfDaysForDate(month, year: year)
                
                pickerView.reloadAllComponents()

            }

        } else {
            
            self.setPickerToCurrentDate(true)
            
        }
        
    }


// MARK:
    
    func numberOfDaysForDate(_ month: Int, year: Int) -> Int {
    
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!
        let range = (calendar as NSCalendar).range(of: .day, in: .month, for: date)
        let numDays = range.length

        return numDays
        
    }
    
    func currentYear() -> Int {
    
        let date = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.year, from: date)
        
        return components.year!

    }

    func currentMonth() -> Int {

        let date = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.month, from: date)
        
        return components.month!

    }

    func currentDay() -> Int {

        let date = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.day, from: date)

        return components.day!

    }
    
    func selectedDateAsString() -> String {
        
        let day: Int = self.selectedRow(inComponent: 0) + 1
        let month: Int = self.selectedRow(inComponent: 1) + 1
        let year: Int = self.currentYear() - yearRangeLength + self.selectedRow(inComponent: 2) + 1
        
        let numberFormatter: NumberFormatter = NumberFormatter.init()
        numberFormatter.minimumIntegerDigits = 2
        
        return String(year) + "-" + numberFormatter.string(from: NSNumber(month))! + "-" + numberFormatter.string(from: day)!
        
    }
    
}
