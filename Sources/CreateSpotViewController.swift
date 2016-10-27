//
//  CreateSpotViewController.swift
//  GeoConfess
//
//  Created by MobileGod on 4/8/16.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import SwiftyJSON

final class CreateSpotViewController: SpotsCreationViewController,
MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet private weak var txtSearch: UITextField!
    @IBOutlet private weak var mapView: MKMapView!
    
    private let searchRadius: CLLocationDistance = 20_000

	// Pin Description Button
    private let PinButton = UIButton(type: .DetailDisclosure)
    private var annotation: MKAnnotation!
    private var localSearch: MKLocalSearch!
    private var localSearchResponse: MKLocalSearchResponse!
    private var pointAnnotation:MKPointAnnotation!
    private var pinAnnotationView:MKPinAnnotationView!
    
	// CoreLocation
    private let locationManager = CLLocationManager()
	
	private var spotsTable: SpotsTableViewController!

	func addSpotTo(spotsTable: SpotsTableViewController) {
		self.spotsTable = spotsTable
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        // Intialize Search Text
        let paddingView = UIView(frame: CGRectMake(0, 0, 10, txtSearch.frame.height))
        txtSearch.leftView = paddingView
        txtSearch.leftViewMode = UITextFieldViewMode.Always
        
        // Initialize Core Location.
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        // Map Initialize - Show the current location on mapview
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func onSearch(sender: AnyObject) {
        if mapView.annotations.count != 0 {
            annotation = mapView.annotations[0]
            mapView.removeAnnotation(annotation)
        }
        
        let localSearchRequest = MKLocalSearchRequest()
		let searchRegion = MKCoordinateRegion(
			center: User.current.location!.coordinate,
			span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
		localSearchRequest.naturalLanguageQuery = txtSearch.text
		localSearchRequest.region = searchRegion
		
        localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.startWithCompletionHandler {
			(searchResponse, error) -> Void in
            if searchResponse == nil {
                let alertController = UIAlertController(
					title: nil, message: "Place Not Found",
					preferredStyle: UIAlertControllerStyle.Alert)
				let dismissAction = UIAlertAction(title: "Dismiss",
					style: UIAlertActionStyle.Default, handler: nil)
				alertController.addAction(dismissAction)
                self.presentViewController(alertController,
					animated: true, completion: nil)
                return
            }
			self.addPinToMap(searchResponse!)
        }
    }
	
	private func addPinToMap(searchResponse: MKLocalSearchResponse) {
		pointAnnotation = MKPointAnnotation()
		pointAnnotation.title = "Confirmer cette adresse"
		pointAnnotation.coordinate = searchResponse.boundingRegion.center
		
		pinAnnotationView = MKPinAnnotationView(
			annotation: pointAnnotation, reuseIdentifier: nil)
		mapView.centerCoordinate = pointAnnotation.coordinate
		mapView.setRegion(MKCoordinateRegionMakeWithDistance(
			pointAnnotation.coordinate, 0.075, 0.075), animated: true)
		mapView.addAnnotation(pinAnnotationView.annotation!)
	}
	
    @IBAction func myLocationButtonTapped(sender: UIButton) {
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - MapView Methods
	
	func mapView(mapView: MKMapView,
	             viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "Spot"
        
        if pinAnnotationView.isKindOfClass(MKAnnotationView) {
            if let pinAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) {
                pinAnnotationView.annotation = annotation
                return pinAnnotationView
            } else {
                
                let pinAnnotationView = MKPinAnnotationView(annotation:annotation, reuseIdentifier:identifier)
                pinAnnotationView.enabled = true
                pinAnnotationView.canShowCallout = true
                pinAnnotationView.animatesDrop = true
                
                let btn = UIButton(type: .ContactAdd)
                pinAnnotationView.rightCalloutAccessoryView = btn
                return pinAnnotationView
            }
        }
        return nil
    }
    
    func mapView(mapView: MKMapView,
                 annotationView view: MKAnnotationView,
				 calloutAccessoryControlTapped control: UIControl) {

		showProgressHUD()
        let geoCoder = CLGeocoder()
		let location = CLLocation(at: pointAnnotation.coordinate)
  
		geoCoder.reverseGeocodeLocation(location) {
			placemarks, error in
			guard let placemark = placemarks?.first else {
				self.hideProgressHUD()
				self.showAlert(title: "Erreur", message: "\(error)")
				return
			}
			let address = placemark.addressDictionary as! [String:AnyObject]
            
			var spotName: String?
			// TODO: Show address information.
			let alertVC = UIAlertController(title: "Nom du lieu?",
			                                message: "",
			                                preferredStyle: .Alert)
			
			// TODO: Do this in a private function.
			alertVC.addTextFieldWithConfigurationHandler {
				textField -> Void in
				textField.placeholder = "Spot Name"
				spotName = textField.text
			}
			let okAction = UIAlertAction(
				title: "Oui",
				style: UIAlertActionStyle.Default) {
					action in
					spotName = alertVC.textFields![0].text
					let whitespaceSet = NSCharacterSet.whitespaceCharacterSet()
					if spotName?.stringByTrimmingCharactersInSet(whitespaceSet) != ""{
						self.createSpot(spotName!,
						                point: self.pointAnnotation, address: address)
					} else {
						let warningAlert = UIAlertController(
							title: "Warning",
							message: "Type the Spot name",
							preferredStyle: UIAlertControllerStyle.Alert
						)
						let acceptAction = UIAlertAction(
						title: "OK", style: UIAlertActionStyle.Default) { (action) in
							
							self.presentViewController(alertVC, animated: true, completion: nil)
						}
						warningAlert.addAction(acceptAction)
						self.presentViewController(warningAlert, animated: true, completion: nil)
					}
			}
			let cancelAction = UIAlertAction(
				title: "Non",
				style: .Default) {
					action in
					self.hideProgressHUD()
                }
			alertVC.addAction(cancelAction)
			alertVC.addAction(okAction)
		
			self.presentViewController(
				alertVC,
				animated: true,
				completion: nil)
        }
    }
	
	private var editRecurrenceTarget: SpotEditor?
	
	private func createSpot(spotName: String, point: MKPointAnnotation,
	                        address addressDictionary: [String: AnyObject]) {
		let address = Address(addressBook: addressDictionary)
		let location = CLLocation(at: point.coordinate)
		spotsTable.createSpot(spotName, address: address, location: location) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success(let spotEditor):
				self.editRecurrenceTarget = spotEditor
				self.performSegueWithIdentifier("editRecurrence", sender: self)
			case .Failure(let error):
				preconditionFailure("\(error)")
			}
		}
	}
	
    // MARK: - CLLocation Methods Delegate
	
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
		print("Error while updating location \(error.localizedDescription)")
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentLocation = locations.last!
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(
			currentLocation.coordinate, 10_000, 10_000)
        mapView.setRegion(coordinateRegion, animated: true)
        mapView.delegate = self
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		switch segue.identifier! {
		case "editRecurrence":
			let singleDateVC = segue.destinationViewController
				as! SingleDateRecurrenceViewController
			singleDateVC.editRecurrence(editRecurrenceTarget!)
		default:
			preconditionFailure()
		}
	}
}
