//
//  StaticSpotViewController.swift
//  GeoConfess
//
//  Created b y Dan on April 16, 2016.
//  Reviewed by Dan Dobrev on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import MapKit

/// Show information about a given static spot.
final class StaticSpotViewController: AppViewControllerWithToolbar {
	
    @IBOutlet weak private var spotNameLabel: UILabel!
    @IBOutlet weak private var spotAddressLabel: UILabel!
    @IBOutlet weak private var recurrencesLabel: UILabel!

    @IBOutlet weak private var routeButton: UIButton!
	
	private var staticSpot: Spot!
	
	static func showSpot(staticSpot: Spot, from sourceVC: AppViewController)
		-> StaticSpotViewController {
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let spotVC = storyboard.instantiateViewControllerWithIdentifier(
			"StaticSpotViewController") as! StaticSpotViewController
		spotVC.staticSpot = staticSpot
		sourceVC.navigationController.pushViewController(spotVC, animated: true)
		return spotVC
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let activity = staticSpot.activityType
		guard case .Static(let spotAddress, let spotRecurrences) = activity else {
			preconditionFailure("Static spot expected")
		}

		spotNameLabel.text = staticSpot.name.uppercaseString
		if let street = spotAddress.street {
			var cityAndState = [String]()
			if let city  = spotAddress.city  { cityAndState.append(city)  }
			if let state = spotAddress.state { cityAndState.append(state) }
			let address = street + "\n" + cityAndState.joinWithSeparator(", ")
			spotAddressLabel.text = address
		}
		if let recurrence = spotRecurrences.first {
			recurrencesLabel.text = recurrence.displayDescription
		}
    }
    
	@IBAction func routeButtonTapped(sender: AnyObject) {
		// Improves static spot address using reverse geocoding.
		let geocoder = CLGeocoder()
		showProgressHUD()
		let spotLocation = staticSpot.location
		geocoder.cachedReverseGeocodeLocation(spotLocation) {
			placemarks, error in
			self.hideProgressHUD()
			let placemark = placemarks?.first
			var spotAddress = self.staticSpot.address!.addressBookDictionary()
			if let geoAddress = placemark?.addressDictionary as? [String: AnyObject] {
				for (key, value) in geoAddress where spotAddress[key] == nil {
					// To be safe, we only add *missing* fields.
					spotAddress[key] = value
				}
			}
			let spotMark = MKPlacemark(coordinate: spotLocation.coordinate,
			                           addressDictionary: spotAddress)
			let spotItem = MKMapItem(placemark: spotMark)
			spotItem.name = self.staticSpot.name
			spotItem.openInMapsWithDefaultOptions()
		}
	}
}

// MARK: - MKMapItem Extensions

extension MKMapItem {

	func openInMapsWithDefaultOptions() {
		let mapType = NSNumber(unsignedLong: MKMapType.Standard.rawValue)
		let options: [String: AnyObject] = [
			MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
			MKLaunchOptionsMapTypeKey: mapType
		]
		self.openInMapsWithLaunchOptions(options)
	}
}
