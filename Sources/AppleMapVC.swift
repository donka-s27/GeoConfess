//
//  AppleMapVC.swift
//  GeoConfess
//
//  Created by Donka on 4/27/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import UIKit
import MapKit

final class AppleMapVC: AppViewControllerWithToolbar, MKMapViewDelegate {

	@IBOutlet weak private var appleMap: MKMapView!
	
	var userMark: MKPlacemark?
	var churchMark: MKPlacemark?
	var source: MKMapItem?
	var destination: MKMapItem?
	var request: MKDirectionsRequest = MKDirectionsRequest()
	var directionsResponse: MKDirectionsResponse = MKDirectionsResponse()
	var route: MKRoute = MKRoute()
	
	var staticspot: Spot!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Prepare Apple Map.
		self.initMapView()
	}
	
	func initMapView() {
		// Prepare pins.
		let userAnnotation = CustomPointAnnotation()
		userAnnotation.title = User.current.name
		userAnnotation.subtitle = String(User.current.role)
		userAnnotation.imageName = "cible-deplacement"
		userAnnotation.coordinate = User.current.location!.coordinate
		
		let churchLocation = staticspot.location
		let churchAnnotation = CustomPointAnnotation()
		churchAnnotation.title = String(self.staticspot.name)
		switch self.staticspot.activityType{
		case .Static(let address, _):
			churchAnnotation.subtitle = String(address.street)
			break
		default:
			break
		}
		churchAnnotation.imageName = "cible-statique"
		churchAnnotation.coordinate = churchLocation.coordinate
		
		// Add pins to Map.
		self.appleMap.addAnnotation(userAnnotation)
		self.appleMap.addAnnotation(churchAnnotation)
		
		// Prepare to display route.
		self.userMark = MKPlacemark(coordinate: User.current.location!.coordinate, addressDictionary: nil)
		self.churchMark = MKPlacemark(coordinate: churchAnnotation.coordinate, addressDictionary: nil)
		self.source = MKMapItem(placemark: userMark!)
		self.destination = MKMapItem(placemark: churchMark!)
		
		self.request = MKDirectionsRequest()
		self.request.source = source
		self.request.destination = destination
		self.request.transportType = MKDirectionsTransportType.Automobile
		self.request.requestsAlternateRoutes = true
		
		// Display route.
		let directions = MKDirections(request: self.request)
		directions.calculateDirectionsWithCompletionHandler { (response, error) in
			if error == nil{
				self.directionsResponse = response!
				self.route = self.directionsResponse.routes[0]
				self.appleMap.addOverlay(self.route.polyline, level: MKOverlayLevel.AboveRoads)
			}
			else{
				print(error)
			}
		}
		appleMap.delegate = self
	}
	
	func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
		let polylineRenderer = MKPolylineRenderer(overlay: overlay)
		if overlay is MKPolyline {
			polylineRenderer.strokeColor = UIColor.redColor()
			polylineRenderer.lineWidth = 5
			return polylineRenderer
		}
		return MKOverlayRenderer()
	}
	
	func mapView(mapView: MKMapView,
	             viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
		if !(annotation is CustomPointAnnotation){
			return nil
		}
		
		let identifier = "pin"
		var view = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
		
		// Set up pin view...
		if view == nil{
			view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
			view!.canShowCallout = true
		}
		else{
			view?.annotation = annotation
		}
		
		// Set image on pin view...
		let cpa = annotation as! CustomPointAnnotation
		view?.image = UIImage(named:cpa.imageName)

		return view
	}
}

class MapPin: NSObject, MKAnnotation{
	var coordinate: CLLocationCoordinate2D
	var title: String?
	var subTitle: String?
	
	init(coordinate: CLLocationCoordinate2D, title: String, subTitle: String) {
		self.coordinate = coordinate
		self.title = title
		self.subTitle = subTitle
	}
}

class CustomPointAnnotation: MKPointAnnotation{
	var imageName: String!
}
