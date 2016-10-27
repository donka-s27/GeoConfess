//
//  SpotsTableViewController.swift
//  GeoConfess
//
//  Created  by Andreas Muller on April 6, 2016.
//  Reviewed by Dan Dobrev on June 8, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import MapKit

/// Controls the **spots list** of the current **priest**.
final class SpotsTableViewController : SpotsCreationViewController,
									   SpotsTableViewCellDelegate,
									   UITableViewDelegate, UITableViewDataSource {
	
	@IBOutlet weak private var tableView: UITableView!
    
	private var spotEditors = [SpotEditor]()
	
	func editPriestSpots() {
		let priest = User.currentPriest!
		spotEditors = SpotEditor.editorsForSpots(priest.staticSpots)
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.registerNib(UINib(nibName: "SpotsTableViewCell", bundle: nil),
                              forCellReuseIdentifier: "SpotsTableViewCell")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
		tableView.reloadData()
    }
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)

		let priest = User.currentPriest!
		let spots = SpotEditor.spotsEditedBy(spotEditors)
		priest.staticSpots = spots
	}
	
    // MARK: - Table View Data and Delegate
    
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return spotEditors.count
    }
    
    func tableView(tableView: UITableView,
                   cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let spotEditor = spotEditors[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(
			"SpotsTableViewCell", forIndexPath: indexPath) as! SpotsTableViewCell
		cell.setSpotEditor(spotEditor, forIndexPath: indexPath)
		cell.delegate = self
        return cell
    }
    
    func tableView(tableView: UITableView,
                   heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 80.0
    }
    
    func tableView(tableView: UITableView,
                   heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(tableView: UITableView,
                   heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
	
	func tableView(tableView: UITableView,
	               willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		return nil
	}

    // MARK: - Editing Spots
	
	private var editRecurrenceTarget: SpotEditor?
	
    func spotEditButtonTapped(cell: SpotsTableViewCell) {
		editRecurrenceTarget = cell.spotEditor
		performSegueWithIdentifier("editRecurrence", sender: self)
    }
    
    func spotTrashButtonTapped(cell: SpotsTableViewCell) {
		let yesAction = {
			self.showProgressHUD()
			cell.spotEditor.spot.deleteSpot(userTokens: User.current.oauth){
				result in
				self.hideProgressHUD()
				switch result {
				case .Success:
					let index = self.spotEditors.indexOf { $0 === cell.spotEditor }!
					self.spotEditors.removeAtIndex(index)
					let indexPath = NSIndexPath(forRow: index, inSection: 0)
					self.tableView.deleteRowsAtIndexPaths([indexPath],
						withRowAnimation: .Left)
				case .Failure(let error):
					preconditionFailure("Delete error: \(error)")
				}
			}
		}
		showYesNoAlert(
			title: "\(cell.spotEditor.spot.name)",
			message: "Voulez-vous supprimer ce lieu?",
			yes: yesAction, no: nil
		)
	}
	
	func createSpot(name: String, address: Address, location: CLLocation,
	                completion: Result<SpotEditor, NSError> -> Void) {
		SpotEditor.createSpot(name, address: address, location: location) {
			result in
			switch result {
			case .Success(let spotEditor):
				self.spotEditors.append(spotEditor)
				self.tableView.reloadData()
				completion(.Success(spotEditor))
			case .Failure(let error):
				preconditionFailure("\(error)")
			}
		}
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		switch segue.identifier! {
		case "editRecurrence":
			let vc = segue.destinationViewController
				as! SingleDateRecurrenceViewController
			vc.editRecurrence(editRecurrenceTarget!)
		case "createSpot":
			let vc = segue.destinationViewController
				as! CreateSpotViewController
			vc.addSpotTo(self)
		default:
			preconditionFailure()
		}
	}
}

// MARK: - Spots Creation View Controller

/// Superclass for all *static spots* creation view controllers.
class SpotsCreationViewController : AppViewControllerWithToolbar {
	
	func popToSpotsTableViewController() {
		for vc in navigationController.viewControllers {
			if let spotsTableVC = vc as? SpotsTableViewController {
				navigationController?.popToViewController(spotsTableVC, animated: true)
				return
			}
		}
		preconditionFailure()
	}
	
	override func availableToMeetButtonTapped(buttton: UIButton) {
		for vc in navigationController.viewControllers {
			if let priestSpotsVC = vc as? PriestSpotsViewController {
				navigationController?.popToViewController(priestSpotsVC, animated: true)
				return
			}
		}
		preconditionFailure()
	}
}
