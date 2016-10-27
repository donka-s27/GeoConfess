//
//  HomePageViewController.swift
//  GeoConfess
//
//  Created  by Dan on 3/1/2016.
//  Reviewed by Dan Dobrev on 5/11/2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import SideMenu
import MapKit

/// Controls the app's main screen (aka, homepage).
final class HomePageViewController: AppViewControllerWithToolbar,
MKMapViewDelegate, UIPopoverPresentationControllerDelegate {
	
	// MARK: - View Controller Lifecyle
	
    override func viewDidLoad() {
        super.viewDidLoad()
		let user = User.current!
		
		// Creates left menu.
		createMenu()
		
		// Start tracking user location.
		user.startLocationTracking {
			trackingAllowed in
			if !trackingAllowed {
				self.showLocalizationTrackingDeniedAlert {
					self.presentLoginViewController()
				}
			}
		}
		
		// Map settings.
		map.delegate = self
		map.showsPointsOfInterest = true
		
		// Updates map when user location is available.
		map.showsUserLocation = false
		user.locationDidBecomeAvailable {
			location in
			let locationString = location.coordinate.shortDescription
			log("Showing user at location \(locationString) on map")
			let region = MKCoordinateRegion(defaultZoomWithCenter: location.coordinate)
			self.map.setRegion(region, animated: true)
			self.map.showsUserLocation = true
		}
		
		// A better map loading experience.
		map.alpha = 0.0
		myLocationButton.alpha = 0.0
		myLocationButton.enabled = false
		showProgressHUD(whiteColor: true)
		mapDidFinishRendering {
			self.hideProgressHUD()
			UIView.animateWithDuration(0.45) {
				self.map.alpha = 1.0
			}
			user.locationDidBecomeAvailable {
				location in
				UIView.animateWithDuration(0.75,
					animations: {
						self.myLocationButton.alpha = 1.0
					},
					completion: {
						animationsFinished in
						self.myLocationButton.enabled = true
					}
				)
			}
		}
    }
	
	private var viewWillAppearTime: CFTimeInterval!
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		viewWillAppearTime = CACurrentMediaTime()
		let user = User.current!
		guard user.active else {
			InactiveUserViewController.presentViewControllerOverCurrent(self)
			return
		}
		
		user.addObserver(self)
		scheduledSpotAnnotationsUpdateBias = 0
		scheduleSpotAnnotationsUpdate(user.nearbySpots)
		presentMenuIfRequested()
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Kills observer if user still exits.
		User.current?.removeObserver(self)
	}

	// MARK: - User Geolocation
	
	@IBOutlet private weak var map: MKMapView!
	@IBOutlet private weak var myLocationButton: UIButton!
	
	@IBAction func myLocationButtonTapped(sender: UIButton) {
		guard let location = User.current.location else { return }
		log("User location: \(location.coordinate)")
		
		let region = MKCoordinateRegion(defaultZoomWithCenter: location.coordinate)
		map.setRegion(region, animated: true)
	}
	
	override func user(user: User, didUpdateLocation location: CLLocation) {
		super.user(user, didUpdateLocation: location)
	}
	
	override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
		super.touchesEnded(touches, withEvent: event)
		#if DEBUG
			guard let userLocation = User.current.location else { return }
			let touch = touches.first!
			let point = touch.locationInView(map)
			let coordinate = map.convertPoint(point, toCoordinateFromView: map)
			let distance = userLocation.distanceFromLocation(CLLocation(at: coordinate))
			let meters = String(format: "%.1f meters", distance)
			print("Tapped at: \(coordinate)")
			print("Distance from user location: \(meters)")
			
		#endif
	}

	// MARK: - Map Loading and Rendering

	private var runWhenMapIsReady: [() -> Void] = [ ]
	private var mapRenderingDone = false
	
	/// Runs the specified callback when map has finish rendering.
	func mapDidFinishRendering(callback: () -> Void) {
		if mapRenderingDone {
			dispatch_async(dispatch_get_main_queue()) { 	callback() }
		} else {
			runWhenMapIsReady.append(callback)
		}
	}
	
	/// This method is called when the map tiles associated with the current
	/// request have been loaded. Map tiles are requested when a new visible
	/// area is scrolled into view and tiles are not already available.
	func mapViewDidFinishLoadingMap(mapView: MKMapView) {
		preconditionIsMainQueue()
	}
	
	/// Map view is about to start rendering some of its tiles.
	func mapViewWillStartRenderingMap(mapView: MKMapView) {
		log("MKMapView rendering...")
		mapRenderingDone = false
	}
	
	/// This method lets you know when the map view finishes rendering all
	/// of the currently visible tiles to the best of its ability. This method
	/// is called regardless of whether all tiles were rendered successfully.
	func mapViewDidFinishRenderingMap(mapView: MKMapView, fullyRendered: Bool) {
		log("MKMapView rendering... OK")
		mapRenderingDone = true
		for callback in runWhenMapIsReady {
			callback()
		}
		runWhenMapIsReady.removeAll()
	}
	
	// MARK: - Rendering Spots on the Map
	
	/// Each spot has a corresponding `MKAnnotation` object.
	///
	/// PS. This is how programming is done in the 21st century.
	/// One of these days I'm gonna frame this and send it up to Bulgaria. 🤔
	private var spotAnnotationsByID = [ResourceID: SpotAnnotation]()

	private var scheduledSpotAnnotationsUpdateBias: Double = 0
	
	/// Only adds the annotations when the map is done loading (and after small ∆t).
	/// Not required at all, but provides a better UX.
	private func scheduleSpotAnnotationsUpdate(currentSpots: Set<Spot>) {
		preconditionIsMainQueue()
		let updatedStartingTime = viewWillAppearTime + 2.5
		var updateDelay = max(updatedStartingTime - CACurrentMediaTime(), 0)
		if updateDelay > 0 {
			// This hacks guarantees the update's correct chronological order.
			updateDelay += 0.05 * scheduledSpotAnnotationsUpdateBias
			scheduledSpotAnnotationsUpdateBias += 1
		}
		let stringUpdateDelay = String(format: "%.2f", updateDelay)
		log("Drawing map spots with \(stringUpdateDelay)s delay...")
		Timer.scheduledTimerWithTimeInterval(updateDelay) {
			guard let user = User.current else { return }
			user.locationDidBecomeAvailable {
			[weak self]
				location in
				self?.mapDidFinishRendering {
					self?.updateSpotAnnotations(currentSpots)
				}
			}
		}
	}
	
	/// Update spot's annotations incrementally.
	private func updateSpotAnnotations(currentSpots: Set<Spot>) {
		var addedCount = 0
		var activeSpotIDs = Set<ResourceID>()
		for spot in currentSpots {
			if let spotAnnotation = spotAnnotationsByID[spot.id] {
				spotAnnotation.spotDidChangeLocation()
			} else {
				let spotAnnotation = SpotAnnotation(forSpot: spot)
				spotAnnotationsByID[spot.id] = spotAnnotation
				map.addAnnotation(spotAnnotation)
				addedCount += 1
			}
			activeSpotIDs.insert(spot.id)
		}
		
		// Deletes old spots. If possible, also animates the spot deletion.
		for (id, spotAnnotation) in spotAnnotationsByID {
			if !activeSpotIDs.contains(id) {
				spotAnnotationsByID[id] = nil
				guard let annotationView = map.viewForAnnotation(spotAnnotation) else {
					map.removeAnnotation(spotAnnotation)
					continue
				}
				let spotAnnotationView = annotationView as! SpotAnnotationView
				spotAnnotationView.willRemoveAnnotationFromMap {
					self.map.removeAnnotation(spotAnnotation)
				}
			}
		}
		
		if addedCount > 0 { log("Adding \(addedCount) new spots to the map") }
		assert(spotAnnotationsByID.count == currentSpots.count)
		assert(Set(spotAnnotationsByID.keys) == Set(currentSpots.map {$0.id}))
	}
	
	func mapView(mapView: MKMapView,
	             viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
		switch annotation {
		case let spotAnnotation as SpotAnnotation:
			var spotAnnotationView = map.dequeueReusableAnnotationViewWithIdentifier(
				SpotAnnotationView.id) as? SpotAnnotationView
			if spotAnnotationView == nil {
				spotAnnotationView = SpotAnnotationView()
			}
			spotAnnotationView!.spotAnnotation = spotAnnotation
			return spotAnnotationView
		default:
			return nil
		}
	}
	
	override func user(user: User, didUpdateNearbySpots spots: Set<Spot>) {
		super.user(user, didUpdateNearbySpots: spots)
		scheduleSpotAnnotationsUpdate(spots)
	}
	
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		switch view {
		case let spotAnnotationView as SpotAnnotationView:
			let spotAnnotation = spotAnnotationView.spotAnnotation
			// There no such thing as a selected spot.
			map.deselectAnnotation(spotAnnotation, animated: false)
			didSelectSpot(spotAnnotation.spot)
		default:
			break
		}
	}
	
	private func didSelectSpot(spot: Spot) {
		let user = User.current!
		switch spot.activityType {
		case .Static:
			StaticSpotViewController.showSpot(spot, from: self)
		case .Dynamic:
			guard spot.priest.id != user.id else {
				self.showAlert(
					title: "Géolocalisation",
					message: "Merci d'avoir activé la géolocalisation! " +
						"Vous recevrez une notification dès qu'un " +
					"pénitent vous enverra une demande de confession.")
				break
			}
			let notifications = user.notificationManager
			if let meetRequest = notifications.meetRequestForPriest(spot.priest.id) {
				MeetRequestViewController.showMeetRequestWithPriest(
					meetRequest, priestLocation: spot.location)
			} else {
				MeetRequestViewController.sendMeetRequestToPriest(
					spot.priest, priestLocation: spot.location)
			}
		}
	}

	// MARK: - Left Menu
	
	private var menuButton: UIBarButtonItem!
	private var sideMenuController: UISideMenuNavigationController!
	
	static var openMenuOnNextPresentation = false
	
	private func createMenu() {
		menuButton = navigationController.navigationBar.highlightedBarButtonWithImage(
			UIImage(named: "Menu Button")!,
			width: 33, hightlightIntensity: 0.3)
		menuButton.buttonView.addTarget(
			self,
			action: #selector(self.menuButtonTapped(_:)),
			forControlEvents: UIControlEvents.TouchUpInside
		)
		menuButton.enabled = true

		navigationItem.leftBarButtonItems = [menuButton]
		MenuViewController.createFor(homePageController: self)
	}
	
	private func presentMenuIfRequested() {
		guard HomePageViewController.openMenuOnNextPresentation else { return }
		HomePageViewController.openMenuOnNextPresentation = false
		presentViewController(SideMenuManager.menuLeftNavigationController!,
		                      animated: true, completion: nil)
	}
	
	@objc private func menuButtonTapped(sender: UIButton) {
		assert(sender === menuButton.buttonView)
		presentViewController(SideMenuManager.menuLeftNavigationController!,
		                      animated: true, completion: nil)
    }
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		let statiContent = segue.destinationViewController
			as? StaticContentViewController
		switch segue.identifier! {
		case "readConfessionFAQ":
			statiContent!.loadContent(title: "LA CONFESSION",
			                          html: "Qu'est ce que la Confession")
		case "readWhyConfess":
			statiContent!.loadContent(title: "LA CONFESSION",
			                          html: "Pourquoi se Confesser")
		case "readConfessionPreparation":
			statiContent!.loadContent(title: "LA CONFESSION",
			                          html: "Comment se Confesser")
		case "readHelp":
			let helpURL = NSURL(string: "http://geoconfess-faq.exproperf.com")!
			statiContent!.loadContent(title: "PAGE D'AIDE", url: helpURL)
		default:
			break
		}
	}
}

// MARK: - SpotAnnotation Class

/// A spot object in the map.
final class SpotAnnotation: NSObject, MKAnnotation {
	
	private var isFirstRendering = true
	private var coordinateAnimationTimer: Timer!
	
	init(forSpot spot: Spot) {
		self.spot = spot
		self.coordinate = spot.location.coordinate
	}
	
	deinit {
		coordinateAnimationTimer?.dispose()
	}

	let spot: Spot
	
	/// Notifies annotation that its spot has changed location.
	/// Provides a simple, linear animation from the *old* location to the *new*.
	func spotDidChangeLocation() {
		let oldCoordinate = coordinate
		let newCoordinate = spot.location.coordinate
		let dlat = newCoordinate.latitude  - oldCoordinate.latitude
		let dlon = newCoordinate.longitude - oldCoordinate.longitude
		
		let animationDuration = 1.0
		let latSpeed = dlat / animationDuration
		let lonSpeed = dlon / animationDuration
		let animationRate  = 1.0/30
		let animationSteps = Int(round(animationDuration / animationRate))
		var currentAnimationStep = 0
		
		coordinateAnimationTimer?.dispose()
		coordinateAnimationTimer = Timer.scheduledTimerWithTimeInterval(
		animationRate, repeats: true) {
			guard currentAnimationStep < animationSteps else {
				self.coordinate = newCoordinate
				self.coordinateAnimationTimer.dispose()
				self.coordinateAnimationTimer = nil
				return
			}
			let dt  = Double(currentAnimationStep) * animationRate
			let lat = oldCoordinate.latitude  + latSpeed*dt
			let lon = oldCoordinate.longitude + lonSpeed*dt
			let stepCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
			self.coordinate = stepCoordinate
			currentAnimationStep += 1
		}
	}

	/// This property *must* be KVO compliant.
	dynamic private(set) var coordinate: CLLocationCoordinate2D {
		didSet {
			assertIsMainQueue()
		}
	}
	
	var title: String? {
		return spot.name
	}
	
	var subtitle: String? {
		switch spot.activityType {
		case .Static(let address, _):
			return address.displayDescription
		case .Dynamic:
			return nil
		}
	}
}

// MARK: - SpotAnnotationView Class

/// Renders the spot on the map.
final class SpotAnnotationView: MKAnnotationView {
	
	static let id = "SpoAnnotationView"
	
	convenience init() {
		self.init(annotation: nil, reuseIdentifier: SpotAnnotationView.id)
		setUp()
	}
	
	override func prepareForReuse() {
		setUp()
	}
	
	private func setUp() {
		enabled = true
		userInteractionEnabled = true
		draggable = false
		image = nil
		alpha = 1.0
		canShowCallout = false
	}
	
	var spotAnnotation: SpotAnnotation! {
		didSet {
			switch spotAnnotation.spot.activityType {
			case .Static:
				image = UIImage(named: "Static Spot Marker")!
			case .Dynamic:
				image = UIImage(named: "Dynamic Spot Marker")!
			}
			let aspectRatio = image!.size.height / image!.size.width
			let width  = CGFloat(45)
			let height = width * aspectRatio
			frame.size = CGSize(width: width, height: height)
			
			// By default, the center of annotation view is placed over
			// the coordinate of the annotation. We use the base for that.
			centerOffset.y = -height/2
			
			guard spotAnnotation.isFirstRendering else { return }
			self.alpha = 0.0
			UIView.animateWithDuration(
				1.50,
				animations: { self.alpha = 1.0 },
				completion: {
					animationsFinished in
					if animationsFinished {
						self.spotAnnotation.isFirstRendering = false
					}
				}
			)
		}
	}
	
	/// Notifies the view that its spot is about to be removed from the map.
	func willRemoveAnnotationFromMap(completion: () -> Void) {
		guard alpha == 1.0 else {
			completion()
			return
		}
		UIView.animateWithDuration(
			6.00,
			animations: { self.alpha = 0.0 },
			completion: {
				animationsFinished in
				completion() // We don't if it has finished or not.
			}
		)
	}
}

// MARK: - Extensions

extension MKCoordinateRegion {
	
	init(defaultZoomWithCenter center: CLLocationCoordinate2D) {
		let kilometersPerDegree = Location.kilometersPerLatitudeDegree
		let span = MKCoordinateSpan(
			latitudeDelta:  10 / kilometersPerDegree,
			longitudeDelta: 10 / kilometersPerDegree)
		
		self.center = center
		self.span = span
	}
}
