//
//  MeetRequestViewController.swift
//  GeoConfess
//
//  Created  by Dan on April 15, 2016.
//  Reviewed by Dan Dobrev on May 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import MapKit

/// Controls the meet request sending/info screen.
final class MeetRequestViewController: AppViewControllerWithToolbar {
	
	private enum Mode {
		case sendToPriest(UserInfo)
		case showMeetRequest(MeetRequest)
	}
	
	private var mode: Mode!
	private var priestUpdatedLocation: CLLocation?
	
	private var priest: UserInfo {
		switch mode! {
		case .sendToPriest(let priest):
			return priest
		case .showMeetRequest(let meetRequest):
			return meetRequest.priest
		}
	}
	
	// MARK: - Pushing the View Controller

	/// Presents the specified meet request view controller.
	static func sendMeetRequestToPriest(priest: UserInfo,
	                                    priestLocation: CLLocation?,
	                                    animated: Bool = true) {
		let mode = Mode.sendToPriest(priest)
		pushViewController(mode, priestLocation: priestLocation, animated: animated)
	}

	/// Presents the specified meet request view controller.
	static func showMeetRequestWithPriest(meetRequest: MeetRequest,
	                                      priestLocation: CLLocation?,
	                                      animated: Bool = true) {
		let mode = Mode.showMeetRequest(meetRequest)
		pushViewController(mode, priestLocation: priestLocation, animated: animated)
	}
	
	private static func pushViewController(mode: Mode, priestLocation: CLLocation?,
	                                       animated: Bool) {
		guard let navigationController = AppNavigationController.current else {
			preconditionFailure()
		}
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let meetRequestVC = storyboard.instantiateViewControllerWithIdentifier(
			"MeetRequestViewController") as! MeetRequestViewController
		
		meetRequestVC.mode = mode
		meetRequestVC.priestUpdatedLocation = priestLocation
		navigationController.pushViewController(	meetRequestVC, animated: animated)
	}
	
	// MARK: - View Controller Logic
	
	@IBOutlet weak private var priestNameLabel: UILabel!
	@IBOutlet weak private var priestDistanceLabel: UILabel!
	@IBOutlet weak private var mainButton: UIButton!
	@IBOutlet weak private var optionalButton: UIButton!
	
	@IBOutlet weak private var mainButtonTopSpace: NSLayoutConstraint!
	private var mainButtonTopSpaceDefaultConstant: CGFloat!
	
	private let sendButtonImage    = UIImage(named: "Envoyer Une Demande Button")!
	private let pendingButtonImage = UIImage(named: "Demande Envoyée Button")!
	private let refusedButtonImage = UIImage(named: "Demande Refusée Button")!
	private let chatButtonImage    = UIImage(named: "Chat Button")!
	private let routeButtonImage   = UIImage(named: "Trouver un Itineraire Button")!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		mainButtonTopSpaceDefaultConstant = mainButtonTopSpace.constant
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		setButtons()
		priestNameLabel.text = priest.name.uppercaseString
		if let distance = stringDistance() {
			priestDistanceLabel.hidden = false
			priestDistanceLabel.text = "à \(distance)"
		} else {
			priestDistanceLabel.hidden = true
		}
	}
	
	private enum ButtonType {
		case sendMeetRequest, pendingMeetRequest, refusedMeetRequest
		case chatWithPriest, traceRouteToPriest
		case none
	}
	
	private func setButton(button: UIButton, type: ButtonType) {
		switch type {
		case .sendMeetRequest:
			button.enabled = true
			button.hidden  = false
			button.setImage(sendButtonImage, forState: .Normal)
			button.setTargetForTap(self, #selector(self.sendMeetRequestButtonTapped(_:)))
		case .pendingMeetRequest:
			button.enabled = false
			button.hidden  = false
			button.setImage(pendingButtonImage, forState: .Normal)
		case .refusedMeetRequest:
			button.enabled = false
			button.hidden  = false
			button.setImage(refusedButtonImage, forState: .Normal)
		case .chatWithPriest:
			button.enabled = true
			button.hidden  = false
			button.setImage(chatButtonImage, forState: .Normal)
			button.setTargetForTap(self, #selector(self.chatButtonTapped(_:)))
		case .traceRouteToPriest:
			button.enabled = true
			button.hidden  = false
			button.setImage(routeButtonImage, forState: .Normal)
			button.setTargetForTap(self, #selector(self.traceRouteButtonTapped(_:)))
		case .none:
			button.enabled = false
			button.hidden  = true
		}
	}
	
	private func setButtons() {
		switch mode! {
		case .sendToPriest:
			setButton(mainButton,     type: .sendMeetRequest)
			setButton(optionalButton, type: .none)
		case .showMeetRequest(let meetRequest):
			switch meetRequest.status {
			case .Pending:
				setButton(mainButton,     type: .pendingMeetRequest)
				setButton(optionalButton, type: .none)
			case .Accepted:
				setButton(mainButton,     type: .chatWithPriest)
				setButton(optionalButton, type: .traceRouteToPriest)
			case .Refused:
				setButton(mainButton,     type: .refusedMeetRequest)
				setButton(optionalButton, type: .none)
			}
		}
		
		// Try centering the only visible button.
		if optionalButton.hidden {
			mainButtonTopSpace.constant = mainButtonTopSpaceDefaultConstant + 15
		} else {
			mainButtonTopSpace.constant = mainButtonTopSpaceDefaultConstant
		}
	}
	
    /// Calculates distance from user to priest.
    private func stringDistance() -> String? {
		guard let priestLocation = priestUpdatedLocation else { return nil }
        let userLocation = User.current.location!
		let distance = userLocation.distanceFromLocation(priestLocation)
		if distance < 999.5 {
			return String(format: "%.0f mètres", distance)
		} else {
			return String(format: "%.1f kilomètres", distance / 1000)
		}
    }
    
    @IBAction func sendMeetRequestButtonTapped(sender: UIButton) {
		let user = User.current!
		let sending = "Sending meet request to \(priest.id)"
		log("\(sending)...")
		assert(user.notificationManager.meetRequestForPriest(priest.id) == nil)
		showProgressHUD()
		user.notificationManager.sendMeetRequestTo(priest.id) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success(let meetRequest):
				self.setButton(self.mainButton, type: .pendingMeetRequest)
				log("\(sending)...OK\n\(meetRequest)")
			case .Failure(let error):
				log("\(sending)...FAILED\n\(error)")
				self.showAlertForError(error)
			}
		}
    }
	
	@IBAction func chatButtonTapped(sender: UIButton) {
		switch mode! {
		case .showMeetRequest(let meetRequest):
			let notificationManager = User.current.notificationManager
			let notification = notificationManager.latestNotificationAbout(meetRequest)
			meetRequest.chatWith(.Priest, from: notification, animated: true)
		case .sendToPriest:
			preconditionFailure()
		}
	}

	@IBAction func traceRouteButtonTapped(sender: UIButton) {
		guard case .showMeetRequest = mode!        else  { preconditionFailure() }
		guard let location = priestUpdatedLocation else  { preconditionFailure() }
		
		// We try a reverse geocoding to find the priest's address.
		let geocoder = CLGeocoder()
		showProgressHUD()
		geocoder.cachedReverseGeocodeLocation(location) {
			placemarks, error in
			self.hideProgressHUD()
			let address = placemarks?.first?.addressDictionary as? [String: AnyObject]
			let spotMark = MKPlacemark(coordinate: location.coordinate,
			                           addressDictionary: address)
			let spotItem = MKMapItem(placemark: spotMark)
			spotItem.name = self.priest.name
			spotItem.openInMapsWithDefaultOptions()
		}
	}
}
