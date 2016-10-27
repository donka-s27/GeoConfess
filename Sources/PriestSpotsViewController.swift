//
//  PriestSpotsViewController.swift
//  GeoConfess
//
//  Created  by Andreas Muller on April 6, 2016.
//  Reviewed by Dan Dobrev on May 9, 2016.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import UIKit

/// Controls the first screen of the **priest spots** workflow.
final class PriestSpotsViewController: AppViewControllerWithToolbar {
	
	class func instantiateViewController() -> PriestSpotsViewController {
		let storyboard = UIStoryboard(name: "PriestSpots", bundle: nil)
		return storyboard.instantiateViewControllerWithIdentifier(
			"PriestSpotsViewController") as! PriestSpotsViewController
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		precondition(User.currentPriest != nil)
	}

    @IBAction func iAmMobileButtonTapped(sender: UIButton) {
		let priest = User.currentPriest!
		showProgressHUD()
		priest.setAvailableToMeet(true) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success:
				self.showAlert(
					title: "Géolocalisation",
					message:
					"Merci d'avoir activé la géolocalisation! " +
					"Vous recevrez une notification dès qu'un " +
					"pénitent vous enverra une demande de confession.") {
						self.navigationController.popViewControllerAnimated(true)
				}
			case .Failure(let error):
				preconditionFailure("setAvailableToMeet failed: \(error)")
			}
		}
	}
	
	override func availableToMeetButtonTapped(buttton: UIButton) {
		navigationController.popViewControllerAnimated(true)
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		precondition(segue.identifier == "editSpots")
		let spotsVC = segue.destinationViewController as! SpotsTableViewController
		spotsVC.editPriestSpots()
	}
}
