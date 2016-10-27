//
//  User.swift
//  GeoConfess
//
//  Created  by Dan Markov on 2/2/2016.
//  Reviewed by Donka Simeonov on 5/10/2016.
//  Copyright © 2016 Dan. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import CoreLocation

// MARK: - User Class

/// Stores information about a given **user** (ie, **priest** or **penitent**).
/// An instance is available after a successful login.
class User: NSObject, Observable, CLLocationManagerDelegate, AppObserver, SpotDelegate {
    
	// MARK: User Properties

	let id: ResourceID
	let active: Bool
	let role: Role
	
	private(set) var name: String
	private(set) var surname: String
	private(set) var email: String

	/// The phone number is *optional*.
	var phoneNumber: String?
	
	/// Sensitive information -- extra care in the future.
	let oauth: OAuthTokens

	/// Manages all user notifications.
	let notificationManager: NotificationManager

	/// The specific user role within the app.
	enum Role: String {
		case Penitent = "user"
		case Priest   = "priest"
		case Admin    = "admin"
	}
	
	/// Loads additional data required for initializing `User` subclass.
	class func loadSubclassData(oauth: OAuthTokens, completion: (JSON?) -> Void) {
		completion(nil)
	}

	// MARK: Creating Users

	required init(oauth: OAuthTokens, userData: JSON, subclassData: JSON?) throws {
		assert(subclassData == nil)
		// Checks all *required* fields.
		guard let id = userData["id"].resourceID else {
			throw userData["id"].error!
		}
		guard let name = userData["name"].string else {
			throw userData["name"].error!
		}
		guard let surName = userData["surname"].string else {
			throw userData["surname"].error!
		}
		guard let active = userData["active"].bool else {
			throw userData["active"].error!
		}
		guard let email = userData["email"].string else {
			throw userData["email"].error!
		}
		guard let role = userData["role"].string else {
			throw userData["role"].error!
		}

		assert(User.isValidEmail(email))
		
		self.id          = id
		self.name        = name
		self.surname     = surName
		self.active      = active
		self.phoneNumber = userData["phone"].string
		self.email       = email
		self.role        = User.Role(rawValue: role)!
		self.oauth       = oauth
		
		self.notificationManager = NotificationManager()
		super.init()
		self.notificationManager.bindUser(self)
		
		let app = App.instance
		app.addObserver(self)
		app.pushNotificationService.subscribeToUserPushes(self)
		applicationWillEnterForeground()
	}
	
	deinit {
		preconditionIsMainQueue()
		tearDownUser()
		log("User deinit completed")
	}
	
	private var userTornDown = false
	
	private func tearDownUser() {
		guard !userTornDown else { return }
		userTornDown = true
		applicationDidEnterBackground()
		deinitLocationTracking()
		let app = App.instance
		app.removeObserver(self)
		app.pushNotificationService.unsubscribeFromUserPushes(self)
	}
	
	func applicationWillEnterForeground() {
		startNearbySpotsRefresh()
		notificationManager.startFetchingNotifications()
	}
	
	func applicationDidEnterBackground() {
		stopNearbySpotsRefresh()
		notificationManager.stopFetchingNotifications()
	}

	func applicationDidUpdateConfiguration(config: App.Configuration) {
		stopNearbySpotsRefresh()
		removeAllCachedNearbySpots()
		startNearbySpotsRefresh()
	}
	
	// MARK: Current User
	
	// FIXME: Is this a security clusterfuck? It sure looks like one.
	static let lastEmailKey = "GeoConfessLastUserEmail"
	static let lastPasswordKey = "GeoConfessLastUserPassword"
	
	/// For security reasons, we should cleanup *all* previously
	/// stored user information from the defaults database.
	private static let oldDefaultKeys = [
		"GeoConfessLastUser"
	]
	
	/// The currently logged in user.
	/// Returns `nil` if no user is available.
	static var current: User! {
		didSet {
			let defaults = NSUserDefaults.standardUserDefaults()
			if current != nil {
				defaults.setObject(current.email, 		   forKey: User.lastEmailKey)
				defaults.setObject(current.oauth.password, forKey: User.lastPasswordKey)
			} else {
				defaults.removeObjectForKey(User.lastPasswordKey)
			}
			for oldKey in oldDefaultKeys {
				defaults.removeObjectForKey(oldKey)
			}
		}
	}

	/// The currently logged in *priest*.
	/// Returns `nil` if there is no user logged in
	/// *or* the current is not a priest.
	static var currentPriest: Priest! {
		guard let user = User.current else { return nil }
		guard let priest = user as? Priest else { return nil }
		assert(priest.role == .Priest)
		return priest
	}

	// MARK: Validating User Properties
	
	/// Email regulax expression.
	/// Solution based on this answer: http://stackoverflow.com/a/25471164/819340
	private static let emailRegex = regex(
		"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
	
	/// Is the *email* format valid?
	static func isValidEmail(email: String) -> Bool {
		return emailRegex.matchesString(email)
	}
	
	/// Is the *password* format valid?
	static func isValidPassword(password: String) -> Bool {
		return password.characters.count >= 6
	}
	
	/// Is the *phone number* format valid?
    static func isValidPhoneNumber(phone: String) -> Bool {
       	let phoneDetector = try! NSDataDetector(
			types: NSTextCheckingType.PhoneNumber.rawValue)
		
		let fullRange = NSMakeRange(0, phone.characters.count)
		let matches = phoneDetector.matchesInString(phone, options: [], range: fullRange)
		if let res = matches.first {
			return res.resultType == .PhoneNumber && NSEqualRanges(res.range, fullRange)
		} else {
			return false
		}
    }
	
	// MARK: Login Workflow

	/// Logins the specified user *asynchronously* in the background.
	/// This methods calls `/oauth/token` and then `/api/v1/me`.
	static func login(username username: String, password: String,
					  completion: (Result<User, Error>) -> Void) {
		let authenticating = "Authenticating user \(username)"
		log("\(authenticating)...")
		requestOAuthTokens(username: username, password: password) {
			result in
			switch result {
			case .Success(let oauthTokens):
				let accessToken = "New access token:\n\(oauthTokens.accessToken)"
				log("\(authenticating)... OK\n\(accessToken)")
				requestUserData(oauthTokens) {
					result -> Void in
					switch result {
					case .Success(let user):
						User.current = user
						completion(.Success(user))
					case .Failure(let error):
						logError("Get user error: \(error)")
						completion(.Failure(error))
					}
				}
			case .Failure(let error):
				log("\(authenticating)... FAILED\n\(error)")
				completion(.Failure(error))
			}
		}
	}
	
	/// Logouts this user *asynchronously* in the background.
	/// You must not hold a *strong reference* to this `User`
 	/// instance after this method returns.
	func logoutInBackground(completion: (Result<Void, Error>) -> Void) {
		let loggingOut = "Logging out user \(email)"
		log("\(loggingOut)...")
		preconditionIsMainQueue()
		tearDownUser()
		revokeOAuth(oauth) {
			[weak self]
			result in
			precondition(self != nil)
			switch result {
			case .Success:
				precondition(User.current === self!)
				#if DEBUG
				let oauth = self!.oauth
				#endif
				User.current = nil // Releases *last* strong ref to user.
				precondition(self == nil, "Logged out user still has strong refs")
				log("\(loggingOut)... OK\n")
				#if DEBUG
					// Is this user actually logged out?
					// Let's find out -- better be safe than sorry :-)
					checkIfOAuthAccessTokenIsValid(oauth) {
						validToken in
						assert(validToken == false)
					}
				#endif
				completion(.Success())
			case .Failure(let error):
				logError("\(loggingOut)... ERROR (\(error))")
				completion(.Failure(error))
			}
		}
	}
	
	/// Updates user information.
	func updateEmail(email: String, name: String, surname: String, phoneNumber: String,
	                 completion: Result<Void, Error> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/users/update.html
		let updateURL = "\(App.serverAPI)/users/\(id)"
		let user: [String: AnyObject] = [
			"email"    : email,
			"password" : oauth.password,
			"name"     : name,
			"surname"  : surname,
			"phone"    : phoneNumber
		]
		let params: [String: AnyObject] = [
			"access_token": oauth.accessToken,
			"user": user
		]
		Alamofire.request(.PUT, updateURL, parameters: params).validate().responseJSON {
			response in
			switch response.result {
			case .Success(let data):
				let json = JSON(data)
				guard json["result"].string == "success" else {
					completion(.Failure(Error(code: .unexpectedServerError)))
					break
				}
				// Update user local info.
				self.email       = email
				self.name        = name
				self.surname     = surname
				self.phoneNumber = phoneNumber
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(Error(causedBy: error)))
			}
		}
	}

	// MARK: User Observers
	
	/// Observers list. The actual type is `ObserverSet<UserObserver>`.
	private var userObservers = ObserverSet()
	
	func addObserver(observer: UserObserver) {
		userObservers.addObserver(observer)
	}
	
	func removeObserver(observer: UserObserver) {
		userObservers.removeObserver(observer)
	}

	/// Fires notification to observers.
	func notifyObservers(notify: (UserObserver) -> Void) {
		userObservers.notifyObservers {
			notify($0 as! UserObserver)
		}
	}

	// MARK: Location Tracking
	
	/// Tracks user's GPS related information.
	private var locationManager: CLLocationManager!
	
	/// User current location.
	/// The value of this property is `nil` if
	/// no location data has ever been retrieved.
	var location: CLLocation? {
		let authStatus = CLLocationManager.authorizationStatus()
		guard authStatus == .AuthorizedAlways else { return nil }
		return locationManager?.location
	}
	
	typealias LocationCallback = (CLLocation) -> Void
	private var locationCallbacks = [LocationCallback]()
	
	/// Registers the specified function to be called
	/// once the `location` property becomes available.
	/// The `completion` function will only be called *once* at most.
	func locationDidBecomeAvailable(completion: LocationCallback) {
		locationCallbacks.append(completion)
		if let location = location {
			notifyLocationIsAvailable(location)
		}
	}
	
	private func notifyLocationIsAvailable(location: CLLocation) {
		dispatch_async(dispatch_get_main_queue()) {
			for callback in self.locationCallbacks {
				callback(location)
			}
			self.locationCallbacks.removeAll()
		}
	}
	
	private func deinitLocationTracking() {
		if locationManager != nil {
			stopLocationTracking()
		}
		locationCallbacks.removeAll()
	}
	
	/// Starts *tracking this user *location*.
	func startLocationTracking(completion: (trackingAllowed: Bool) -> Void) {
		precondition(locationManager == nil)
		
		func callCompletion(trackingAllowed: Bool) {
			dispatch_async(dispatch_get_main_queue()) {
				completion(trackingAllowed: trackingAllowed)
			}
		}
		func startUpdatingLocation() {
			precondition(CLLocationManager.locationServicesEnabled())
			log("Starting location updates...")
			precondition(CLLocationManager.locationServicesEnabled())
			locationManager.startUpdatingLocation()
		}
		
		isFirstLocation = true
		isFirstDidChangeAuthorizationStatus = true
		let authStatus = CLLocationManager.authorizationStatus()
		log("Current location authorization status: \(authStatus)")
		switch authStatus {
		case .NotDetermined:
			// If the current authorization status is anything other than
			// .NotDetermined, the requestAlwaysAuthorization method does nothing and
			// does not call the locationManager:didChangeAuthorizationStatus: method.
			locationManager = CLLocationManager()
			locationManager.delegate = self
			locationManager.requestAlwaysAuthorization()
			onDidChangeAuthorizationStatus = {
				status in
				switch status {
				case .AuthorizedAlways:
					startUpdatingLocation()
					callCompletion(true)
				case .NotDetermined, .AuthorizedWhenInUse, .Denied, .Restricted:
					callCompletion(false)
				}
			}
			return
		case .AuthorizedAlways:
			locationManager = CLLocationManager()
			locationManager.delegate = self
			startUpdatingLocation()
			callCompletion(true)
		case .AuthorizedWhenInUse, .Denied, .Restricted:
			callCompletion(false)
		}
	}
	
	func stopLocationTracking() {
		precondition(locationManager != nil)
		locationManager.stopUpdatingLocation()
		locationManager = nil
	}
	
	private var isFirstLocation: Bool!

	func locationManager(manager: CLLocationManager,
	                     didUpdateLocations locations: [CLLocation]) {
		var mostAccurateLocation = locations[0]
		for location in locations[1..<locations.count] {
			if location.horizontalAccuracy < mostAccurateLocation.horizontalAccuracy {
				mostAccurateLocation = location
			}
		}
		if isFirstLocation! {
			let stringLocation = mostAccurateLocation.coordinate.shortDescription
			log("Starting location updates... OK (location: \(stringLocation))")
			isFirstLocation = false
		}
		notifyObservers {
			$0.user(self, didUpdateLocation: mostAccurateLocation)
		}
		notifyLocationIsAvailable(mostAccurateLocation)
	}
	
	func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
		precondition(error.domain == kCLErrorDomain)
		log("Core location failed with error:\n\(error.readableDescription)")
	}

	/// The first method call seems to just repeat the initial auth state
	/// and, as such, is pretty much useless (and should be ignored).
	private var isFirstDidChangeAuthorizationStatus: Bool!
	
	private var onDidChangeAuthorizationStatus: (CLAuthorizationStatus -> Void)!
	
	/// As far as we can tell, this method is *always* called
	/// after a new `CLLocationManager` instance is created.
	func locationManager(manager: CLLocationManager,
	                     didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		log("Location authorization status did change: \(status)")
		guard !isFirstDidChangeAuthorizationStatus else {
			log("location authorization status change ignored")
			isFirstDidChangeAuthorizationStatus = false
			return
		}
		guard onDidChangeAuthorizationStatus == nil else {
			onDidChangeAuthorizationStatus(status)
			onDidChangeAuthorizationStatus = nil
			return
		}
		switch status {
		case .AuthorizedAlways:
			/* This should be detected on the next login. */
			break
		case .NotDetermined, .AuthorizedWhenInUse, .Denied, .Restricted:
			notifyObservers {
				$0.userDidDenyLocalizationTracking(self)
			}
		}
	}
	
	// MARK: Caching Nearby Spots
	
	/// All *active* spots *near* this user.
	/// Updates sent via `UserObserver` protocol.
	var nearbySpots: Set<Spot> = [ ] {
		willSet {
			precondition(NSThread.isMainThread())
		}
		didSet {
			for spot in oldValue    { spot.delegate = nil  }
			for spot in nearbySpots { spot.delegate = self }
			if nearbySpots != oldValue {
				notifyObservers {
					$0.user(self, didUpdateNearbySpots: self.nearbySpots)
				}
			}
		}
	}
	
	func spotLocationDidUpdate(spot: Spot, newLocation: CLLocation) {
		precondition(nearbySpots.contains(spot))
		notifyObservers {
			$0.user(self, didUpdateNearbySpots: self.nearbySpots)
		}
	}
	
	//private var spotsRefreshTimer: Timer?
	
	private static var spotsRefreshQueueID = 0
	private var spotsRefreshQueue: dispatch_queue_t!
	
	private func startNearbySpotsRefresh() {
		precondition(NSThread.isMainThread())
		precondition(spotsRefreshQueue == nil)
		let queueName = "gc.spots-refresh-queue-\(User.spotsRefreshQueueID)"
		User.spotsRefreshQueueID += 1
		spotsRefreshQueue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL)
		
		locationDidBecomeAvailable {
			location in
			let targetQueue = self.spotsRefreshQueue
			dispatch_async(targetQueue) {
				[weak self] in
				guard let user = self else { return }
				guard targetQueue === user.spotsRefreshQueue else { return }
				user.updateNearbySpotsCacheAt(location)
			}
		}
	}

	private func stopNearbySpotsRefresh() {
		guard spotsRefreshQueue != nil else { return }
		precondition(NSThread.isMainThread())
		let queueAboutToBeReleased = spotsRefreshQueue
		spotsRefreshQueue = nil
		dispatch_sync(queueAboutToBeReleased) {
			/* Blocks until queue is empty. */
		}
	}
	
	func removeAllCachedNearbySpots() {
		precondition(NSThread.isMainThread())
		nearbySpots.removeAll()
	}

	private func updateNearbySpotsCacheAt(userLocation: CLLocation) {
		precondition(NSThread.isMainThread() == false)
		let running = "Updating spots"
		log("\(running)...")
		
		func scheduleNextUpdateWithTimeInterval(interval: Double) {
			let nanoseconds = Int64(round(interval * 1e9))
			let time = dispatch_time(DISPATCH_TIME_NOW, nanoseconds)
			let targetQueue = spotsRefreshQueue
			guard targetQueue != nil else { return }
			dispatch_after(time, targetQueue) {
				[weak self] in
				guard let user = self else { return }
				guard targetQueue === user.spotsRefreshQueue else { return }
				user.updateNearbySpotsCacheAt(user.location!)
			}
		}
		
		let coordinate = userLocation.coordinate
		let radius = spotsMaxRadiusInKm
		let active = showOnlyActiveSpots
		let targetQueue = spotsRefreshQueue
		Spot.getSpotsNearLocation(coordinate, radius, onlyActive: active, targetQueue) {
			result in
			precondition(NSThread.isMainThread() == false)
			guard targetQueue === self.spotsRefreshQueue else { return }
			let currentRadius = self.spotsMaxRadiusInKm
			let currentActive = self.showOnlyActiveSpots
			guard radius == currentRadius && active == currentActive else {
				scheduleNextUpdateWithTimeInterval(self.spotsRefreshRate)
				return
			}
			switch result {
			case .Success(let spots):
				let stringlocation = userLocation.coordinate.shortDescription
				log("\(running)... OK (\(spots.count) spots near \(stringlocation))")
				scheduleNextUpdateWithTimeInterval(self.spotsRefreshRate)
				dispatch_sync(dispatch_get_main_queue()) {
					self.nearbySpots = self.replaceDynamicSpotIfNeeded(spots)
				}
			case .Failure(let error):
				let wait = randomDoubleInRange(4...8)
				log("\(running)... FAILED\n\(error)")
				log("Will try again in \(wait) seconds...")
				scheduleNextUpdateWithTimeInterval(wait)
			}
		}
	}
	
	private var spotsRefreshRate: NSTimeInterval {
		let key = "User Spots Refresh Rate (seconds)"
		let refreshRate = (App.instance.properties[key]! as! NSNumber).doubleValue
		assert(refreshRate > 0)
		return refreshRate
	}

	private var spotsMaxRadiusInKm: Double {
		let key = "User Spots Max Radius (km)"
		let radius = (App.instance.properties[key]! as! NSNumber).doubleValue
		assert(radius > 0)
		return radius
	}
	
	private var showOnlyActiveSpots: Bool {
		let key = "Show Only Active Spots on the Map"
		let value = (App.instance.properties[key]! as! NSNumber).boolValue
		return value
	}
	
	// MARK: Hooking up Dynamic Spot
	
	private func replaceDynamicSpotIfNeeded(spots: Set<Spot>) -> Set<Spot> {
		var canonicalSpots = Set<Spot>()
		for spot in spots {
			if shouldBeReplacedByDynamicSpot(spot) {
				if let dynamicSpot = self.dynamicSpot {
					canonicalSpots.insert(dynamicSpot)
				}
			} else {
				canonicalSpots.insert(spot)
			}
		}
		return canonicalSpots
	}
	
	func shouldBeReplacedByDynamicSpot(spot: Spot) -> Bool {
		return false
	}
	
	var dynamicSpot: Spot? {
		didSet {
			if let oldValue = oldValue {
				nearbySpots.remove(oldValue)
			}
			if let dynamicSpot = dynamicSpot {
				nearbySpots.insert(dynamicSpot)
			}
		}
	}
}

// MARK: - User Observer Protocol

/// User model events.
protocol UserObserver: class, Observer {
	
	/// Property `location` was updated.
	func user(user: User, didUpdateLocation location: CLLocation)
	
	/// Property `nearbySpots` was updated.
	func user(user: User, didUpdateNearbySpots spots: Set<Spot>)
	
	/// Authorization for location tracking has being *denied* by the user.
	///
	/// Only changes to the authorization status are reported.
	/// For instance, if user denies tracking when `startLocationTracking`
	/// is called, this method will *not* be called.
	///
	/// The expected behavior here is to logout the unauthorized user.
	func userDidDenyLocalizationTracking(user: User)
}

// MARK: - OAuthTokens Struct

/// Stores OAuth tokens returned from a successful authentication.
struct OAuthTokens {
	let accessToken: String
	let refreshToken: String
	let tokenType: String
	let createdAt: Double

	/// Sensitive information -- extra care in the future.
	let password: String

	init(oauthResponse: JSON, password: String) throws {
		precondition(User.isValidPassword(password))
		guard let accessToken = oauthResponse["access_token"].string else {
			throw oauthResponse["access_token"].error!
		}
		guard let refreshToken = oauthResponse["refresh_token"].string else {
			throw oauthResponse["refresh_token"].error!
		}
		guard let tokenType = oauthResponse["token_type"].string else {
			throw oauthResponse["token_type"].error!
		}
		guard let createdAt = oauthResponse["created_at"].double else {
			throw oauthResponse["created_at"].error!
		}
		self.accessToken  = accessToken
		self.refreshToken = refreshToken
		self.tokenType    = tokenType
		self.createdAt    = createdAt
		self.password     = password
	}
}

// MARK: -

/// Requests OAuth authorization (aka, *login*)..
private func requestOAuthTokens(username username: String,
								password: String,
								completion: Result<OAuthTokens, Error> -> Void) {
	precondition(User.isValidEmail(username))
	precondition(User.isValidPassword(password))
	
	// The corresponding API is documented here:
	// http://geoconfess.herokuapp.com/apidoc/V1/credentials/show.html
	let oauthURL = "\(App.serverURL)/oauth/token"
	let params = [
		"grant_type": "password",
		"username":    username,
		"password":    password,
		"os": 		  "ios",
        "push_token": "3kjh123iu42i314g123"
	]
	
	Alamofire.request(.POST, oauthURL, parameters: params).validate().responseJSON {
		response in
		preconditionIsMainQueue()
		switch response.result {
		case .Success(let value):
			do {
				let tokens = try OAuthTokens(
					oauthResponse: JSON(value), password: password)
				completion(.Success(tokens))
			} catch let error as NSError {
				completion(.Failure(Error(causedBy: error)))
			}
		case .Failure(let error):
			completion(.Failure(Error(causedBy: error)))
		}
	}
}

/// Revokes OAuth authorization (aka, *logout*).
private func revokeOAuth(oauthTokens: OAuthTokens,
                         completion: Result<Void, Error> -> Void) {
	// Following advice given by Oleg Sulyanov over HTTP headers.
	let revokeURL = "\(App.serverURL)/oauth/revoke"
	let headers = [
		"Authorization": "\(oauthTokens.tokenType) \(oauthTokens.accessToken)"
	]
	let params = ["token": oauthTokens.accessToken]
	let http = Alamofire.request(.POST, revokeURL, parameters: params, headers: headers)
	http.validate().responseJSON {
		response in
		switch response.result {
		case .Success:
			completion(.Success())
		case .Failure(let error):
			completion(.Failure(Error(causedBy: error)))
		}
	}
}

/// Requests user information.
private func requestUserData(oauthTokens: OAuthTokens, suppressLogging: Bool = false,
                             completion: (Result<User, Error>) -> Void) {
	func log(msg: String) {
		if suppressLogging { return }
		GeoConfess.log("Getting user data\(msg)")
	}
	
	// This API endpoint is documented here:
	// http://geoconfess.herokuapp.com/apidoc/V1/credentials/show.html
	let meURL = "\(App.serverAPI)/me"
	let params = ["access_token": oauthTokens.accessToken]
	
	log("...")
	Alamofire.request(.GET, meURL, parameters: params).validate().responseJSON {
		response in
		preconditionIsMainQueue()
		switch response.result {
		case .Success(let data):
			let userData = JSON(data)
			let role = User.Role(rawValue: userData["role"].string!)!
			log("... OK \nUser:\n\(userData)")
			
			let userClass: User.Type
			switch role {
			case .Penitent:	userClass = Penitent.self
			case .Priest:   userClass = Priest.self
			case .Admin:    userClass = User.self
			}
			userClass.loadSubclassData(oauthTokens) {
				subclassData in
				do {
					let user = try userClass.init(
						oauth: oauthTokens,
						userData: userData,
						subclassData: subclassData)
					completion(.Success(user))
				} catch let error as NSError {
					completion(.Failure(Error(causedBy: error)))
				}
			}
		case .Failure(let error):
			log("... FAILED\n\(error.readableDescription)")
			completion(.Failure(Error(causedBy: error)))
		}
	}
}

/// Just for testing purposes.
private func checkIfOAuthAccessTokenIsValid(oauthTokens: OAuthTokens,
                                            validToken: Bool -> Void) {
	let checking = "Checking if access token successfully revoked"
	log("\(checking)...")
	requestUserData(oauthTokens, suppressLogging: true) {
		result in
		let accessToken = "access token:\n\(oauthTokens.accessToken)"
		switch result {
		case .Success:
			log("\(checking)... FAILED\nStill valid \(accessToken)")
			validToken(true)
		case .Failure:
			log("\(checking)... OK\nRevoked \(accessToken)")
			validToken(false)
		}
	}
}
