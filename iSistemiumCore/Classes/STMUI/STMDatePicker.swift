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
    
    func setPickerToCurrentDate(animated: Bool) {
        
        self.selectRow(self.currentDay() - 1, inComponent: 0, animated: animated)
        self.selectRow(self.currentMonth() - 1, inComponent: 1, animated: animated)
        self.selectRow(yearRangeLength - 1, inComponent: 2, animated: animated)

    }
    
    
//MARK: - UIPickerViewDataSource

    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 3
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
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

    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        var stringToShow: String
        
        if component == 2 {
            
            stringToShow = String(self.currentYear() - yearRangeLength + row + 1)
            
        } else {
            
            let numberFormatter: NSNumberFormatter = NSNumberFormatter.init()
            numberFormatter.minimumIntegerDigits = 2

            stringToShow = numberFormatter.stringFromNumber(row + 1)!
            
        }
        
        return stringToShow
        
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let dateComponents = NSDateComponents()
        dateComponents.day = pickerView.selectedRowInComponent(0) + 1
        dateComponents.month = pickerView.selectedRowInComponent(1) + 1
        dateComponents.year = self.currentYear() - yearRangeLength + pickerView.selectedRowInComponent(2) + 1
        
        let calendar = NSCalendar.currentCalendar()
        let date = calendar.dateFromComponents(dateComponents)!

        if date.compare(NSDate()) == NSComparisonResult.OrderedAscending {
        
            if component > 0 {
                
                let month: Int = pickerView.selectedRowInComponent(1) + 1
                let year: Int = self.currentYear() - yearRangeLength + pickerView.selectedRowInComponent(2) + 1
                
                numberOfDays = numberOfDaysForDate(month, year: year)
                
                pickerView.reloadAllComponents()

            }

        } else {
            
            self.setPickerToCurrentDate(true)
            
        }
        
    }


// MARK:
    
    func numberOfDaysForDate(month: Int, year: Int) -> Int {
    
        let dateComponents = NSDateComponents()
        dateComponents.year = year
        dateComponents.month = month
        
        let calendar = NSCalendar.currentCalendar()
        let date = calendar.dateFromComponents(dateComponents)!
        let range = calendar.rangeOfUnit(.Day, inUnit: .Month, forDate: date)
        let numDays = range.length

        return numDays
        
    }
    
    func currentYear() -> Int {
    
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Year, fromDate: date)
        
        return components.year

    }

    func currentMonth() -> Int {

        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Month, fromDate: date)
        
        return components.month

    }

    func currentDay() -> Int {

        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Day, fromDate: date)

        return components.day

    }
    
    func selectedDateAsString() -> String {
        
        let day: Int = self.selectedRowInComponent(0) + 1
        let month: Int = self.selectedRowInComponent(1) + 1
        let year: Int = self.currentYear() - yearRangeLength + self.selectedRowInComponent(2) + 1
        
        let numberFormatter: NSNumberFormatter = NSNumberFormatter.init()
        numberFormatter.minimumIntegerDigits = 2
        
        return String(year) + "-" + numberFormatter.stringFromNumber(month)! + "-" + numberFormatter.stringFromNumber(day)!
        
    }
    
}
