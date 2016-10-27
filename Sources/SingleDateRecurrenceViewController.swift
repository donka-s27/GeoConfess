//
//  SingleDateRecurrenceViewController.swift
//  GeoConfess
//
//  Created by Andreas Muller on April 8, 2016.
//  Reviewd by Dan on June 7, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import DownPicker
import CoreLocation
import SwiftyJSON
import Alamofire

/// Editor for recurrences with *single date* schedule.
final class SingleDateRecurrenceViewController : SpotsCreationViewController {
	
	private var spotEditor: SpotEditor!
	private var resetDateAndTime = false
	
	func editRecurrence(spotEditor: SpotEditor) {
		self.spotEditor = spotEditor
		resetDateAndTime = true
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		initTimeFields()
        initDateField()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
		precondition(spotEditor != nil)
		
		if resetDateAndTime {
			if let singleDate = spotEditor.recurrenceSingleDate {
				let recurrence = spotEditor.recurrence!
				dateField.text = dateFormatter.stringFromDate(singleDate.toNSDate())
				startHourField.text = recurrence.startAt.stringHour
				startMinsField.text = recurrence.startAt.stringMinute
				stopHourField.text  = recurrence.stopAt.stringHour
				stopMinsField.text  = recurrence.stopAt.stringMinute
			} else {
				dateField.text = nil
				startHourField.text = nil
				startMinsField.text = nil
				stopHourField.text  = nil
				stopMinsField.text  = nil
			}
			resetDateAndTime = false
		}
    }
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
	}
	
	// MARK: - Editing Time
	
	@IBOutlet weak private var startHourField: UITextField!
	@IBOutlet weak private var startMinsField: UITextField!
	@IBOutlet weak private var stopHourField: UITextField!
	@IBOutlet weak private var stopMinsField: UITextField!
	
	private var startHourPicker: DownPicker!
	private var startMinsPicker: DownPicker!
	private var stopHourPicker: DownPicker!
	private var stopMinsPicker: DownPicker!
	
	private func initTimeFields() {
		var hours = [String]()
		for h in 0...23  {
			hours.append(String(format: "%02d", h))
		}
		var minutes = [String]()
		for m in 0...59 {
			minutes.append(String(format: "%02d", m))
		}
		self.startHourPicker = DownPicker(textField: startHourField, withData: hours)
		self.startMinsPicker = DownPicker(textField: startMinsField, withData: minutes)
		self.stopHourPicker  = DownPicker(textField: stopHourField,  withData: hours)
		self.stopMinsPicker =  DownPicker(textField: stopMinsField,  withData: minutes)
	}

	// MARK: - Editing Date
	
	@IBOutlet weak private var dateField: UITextField!

	private let datePickerView = UIDatePicker()
	private var previousDate: String!

	private let dateFormatter: NSDateFormatter = {
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		return dateFormatter
	}()
	
    private func initDateField() {
        datePickerView.datePickerMode = UIDatePickerMode.Date
        
        // Add toolbar with Cancel and Done buttons.
        let toolbar = UIToolbar()
        toolbar.barStyle = .Default
        toolbar.sizeToFit()
        
        let space = UIBarButtonItem(
			barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
			barButtonSystemItem: .Done, target: self,
			action: #selector(self.datePickerDoneTapped(_:)))
        let cancelButton = UIBarButtonItem(
			barButtonSystemItem: .Cancel, target: self,
			action: #selector(self.datePickerCancelTapped(_:)))
        
        toolbar.setItems([cancelButton, space, doneButton], animated: true)
		dateField.inputView = datePickerView
		dateField.inputAccessoryView = toolbar
		
		dateField.addTarget(
			self, action: #selector(self.dateFieldDidTouchDown(_:)),
			forControlEvents: .TouchDown)
		
        datePickerView.addTarget(
			self, action: #selector(self.datePickerValueChanged(_:)),
			forControlEvents: .ValueChanged)
		
		// Make placeholder text color of DateText white.
		dateField.attributedPlaceholder = NSAttributedString(
			string:"Date",
			attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
    }
    
	@objc private func dateFieldDidTouchDown(sender: UITextField) {
		previousDate = dateField.text
		if dateField.text == nil || dateField.text == "" {
			// If empty, make it current date.
			dateField.text = dateFormatter.stringFromDate(NSDate())
		}
		datePickerView.date = dateFormatter.dateFromString(dateField.text!)!
	}
	
	@objc private func datePickerValueChanged(sender: UIDatePicker) {
        dateField.text = dateFormatter.stringFromDate(sender.date)
    }
    
    @objc private func datePickerDoneTapped(sender: UIButton) {
        dateField.resignFirstResponder()
        datePickerValueChanged(datePickerView)
    }
    
    @objc private func datePickerCancelTapped(sender: UIButton) {
        dateField.resignFirstResponder()
        dateField.text = previousDate
    }
	
	// MARK: - Creating or Updating Recurrence

	@IBAction func createRecurrenceButtonTapped(sender: UIButton) {
		// Validates date.
		guard let date = dateFormatter.dateFromString(dateField.text!) else {
			showAlert(title: "Date", message: "S'il vous plaît sélectionner une date")
			return
		}
		let schedule = Recurrence.Schedule.SingleDate(Date(fromDate: date))
		
		// Validates time.
		guard let startAt = timeFrom(hour: startHourField, min: startMinsField) else {
			showAlert(title: "Démarrer",
			          message: "Sélectionner l'heure de début valide.")
			return
		}
		guard let stopAt = timeFrom(hour: stopHourField, min: stopMinsField) else {
			showAlert(title: "Arrêtez",
			          message: "sélectionnez l'heure de fin de validité.")
			return
		}
		guard startAt <= stopAt else {
			showAlert(title: "Heures",
			          message: "Sélectionnez l'heure de début et de fin correctement.")
			return
		}
		
		showProgressHUD()
		spotEditor.setRecurrence(startAt: startAt, stopAt: stopAt, at: schedule) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success:
				self.popToSpotsTableViewController()
			case .Failure(let error):
				preconditionFailure("Saving error: \(error)")
			}
		}
	}

	// MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		switch segue.identifier! {
		case "editWeeklyRecurrence":
			let weeklyVC = segue.destinationViewController
				as! WeeklyRecurrenceViewController
			let startAt = timeFrom(hour: startHourField, min: startMinsField)
			let stopAt  = timeFrom(hour: stopHourField,  min: stopMinsField)
			weeklyVC.editRecurrence(spotEditor, startAt: startAt, stopAt: stopAt)
		default:
			preconditionFailure("Unexpected segue")
		}
	}
}

extension Time {
	
	var stringHour: String {
		return String(format: "%.2d", self.hour)
	}
	
	var stringMinute: String {
		return String(format: "%.2d", self.minute)
	}
}

extension SpotsCreationViewController {

	func timeFrom(hour hour: UITextField, min: UITextField) -> Time? {
		let hourValue = UInt(hour.text!)
		let minValue  = UInt(min.text!)
		guard hourValue != nil && minValue != nil else { return nil }
		return Time(hour: hourValue!, minute: minValue!)
	}
}

