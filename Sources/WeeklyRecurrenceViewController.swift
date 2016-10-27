//
//  WeeklyRecurrenceViewController.swift
//  GeoConfess
//
//  Created by Andreas Muller on April 4, 2016.
//  Reviewd by Dan on June 11, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import DownPicker
import SwiftyJSON

/// Editor for recurrences with *weekly* schedule.
final class WeeklyRecurrenceViewController : SpotsCreationViewController {
    
	private var spotEditor: SpotEditor!
	private var resetWeekdaysAndTime = false
	private var initialStartTime: Time?, initialStopTime: Time?
	
	func editRecurrence(spotEditor: SpotEditor, startAt: Time?, stopAt: Time?) {
		self.spotEditor = spotEditor
		resetWeekdaysAndTime = true
		initialStartTime = startAt
		initialStopTime  = stopAt
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		initTimeFields()
		initWeekdaysFields()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
		precondition(spotEditor != nil)
		
		if resetWeekdaysAndTime {
			if let recurrenceWeekdays = spotEditor.recurrenceWeekdays {
				let recurrence = spotEditor.recurrence!
				for weekday in Weekday.week {
					setWeekdayButton(weekday,
					                 checked: recurrenceWeekdays.contains(weekday))
				}
				startHourField.text = recurrence.startAt.stringHour
				startMinsField.text = recurrence.startAt.stringMinute
				stopHourField.text  = recurrence.stopAt.stringHour
				stopMinsField.text  = recurrence.stopAt.stringMinute
			} else {
				for weekday in Weekday.week {
					setWeekdayButton(weekday, checked: false)
				}
				startHourField.text = initialStartTime?.stringHour
				startMinsField.text = initialStartTime?.stringMinute
				stopHourField.text  = initialStopTime?.stringHour
				stopMinsField.text  = initialStopTime?.stringMinute
			}
			resetWeekdaysAndTime = false
		}
    }
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
	}

	// MARK: - Editing Weekdays
	
	@IBOutlet weak private var mondayButton:    UIButton!
	@IBOutlet weak private var tuesdayButton:   UIButton!
	@IBOutlet weak private var wednesdayButton: UIButton!
	@IBOutlet weak private var thursdayButton:  UIButton!
	@IBOutlet weak private var fridayButton:    UIButton!
	@IBOutlet weak private var saturdayButton:  UIButton!
	@IBOutlet weak private var sundayButton:    UIButton!
	
	private let checkedImage    = UIImage(named: "icn_Checked")!
	private let uncheckedImage  = UIImage(named: "icn_UnChecked")!
	
	private var weekdayButtons: [Weekday: UIButton] = [:]
	
	private func weekdayForButton(target: UIButton) -> Weekday {
		for (weekday, button) in weekdayButtons {
			if button === target { return weekday }
		}
		preconditionFailure()
	}
	
	private func initWeekdaysFields() {
		weekdayButtons.removeAll()
		weekdayButtons[.Monday]    = mondayButton
		weekdayButtons[.Tuesday]   = tuesdayButton
		weekdayButtons[.Wednesday] = wednesdayButton
		weekdayButtons[.Thursday]  = thursdayButton
		weekdayButtons[.Friday]    = fridayButton
		weekdayButtons[.Saturday]  = saturdayButton
		weekdayButtons[.Sunday]    = sundayButton
	}

	private func setWeekdayButton(weekday: Weekday, checked: Bool) {
		// You can check this formula from autolayout in storyboard (aka, a f*?! hack).
		let buttonSize = CGSize(width: view.bounds.size.width * 0.5 * 0.7,
		                        height: 20.0)
		let imageSize  = CGSize(width: checkedImage.size.width,
		                        height: checkedImage.size.height)
		
		let button = weekdayButtons[weekday]!
		button.imageEdgeInsets = UIEdgeInsets(
			top: 0, left: 0,
			bottom: 0, right: buttonSize.width - buttonSize.height)
		button.titleEdgeInsets = UIEdgeInsets(
			top: 0, left: buttonSize.height - imageSize.width,
			bottom: 0, right: 0)
		
		if checked {
			button.setImage(UIImage(named: "icn_Checked"), forState: .Normal)
			button.tag = 1
		} else {
			button.setImage(UIImage(named: "icn_UnChecked"), forState: .Normal)
			button.tag = 0
		}
		button.setTitle(weekday.localizedName, forState: .Normal)
	}
	
	@IBAction func weekdayButtonTapped(sender: UIButton) {
		sender.tag = sender.tag == 0 ? 1 : 0
		setWeekdayButton(weekdayForButton(sender), checked: sender.tag == 1)
	}
	
	// MARK: - Editing Time

	@IBOutlet weak private var startHourField: UITextField!
	@IBOutlet weak private var startMinsField: UITextField!
	@IBOutlet weak private var stopHourField:  UITextField!
	@IBOutlet weak private var stopMinsField:  UITextField!
	
	private var startHourPicker: DownPicker!
	private var startMinsPicker: DownPicker!
	private var stopHourPicker:  DownPicker!
	private var stopMinsPicker:  DownPicker!
	
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
	
	// MARK: - Creating or Updating Recurrence

    // Create Recurrence with WeekDays
    @IBAction func createRecurrenceButtonTapped(sender: UIButton) {
		// Validates weekdays.
		var selectedWeekdays = Set<Weekday>()
		for (weekday, button) in weekdayButtons {
			if button.tag == 1 {
				selectedWeekdays.insert(weekday)
			}
		}
		guard selectedWeekdays.count > 0 else {
			showAlert(title: "journées",
			          message: "S'il vous plaît sélectionner au moins un jour")
			return
		}
		let schedule = Recurrence.Schedule.Weekly(selectedWeekdays)

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
}
