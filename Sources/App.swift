//
//  AppDelegate.swift
//  GeoConfess
//
//  Created by Donka on February 26, 2016.
//  Reviewed by Dan Dobrev on May 18, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import AWSS3
import AWSCore
import GoogleMaps
import SwiftyJSON
import Alamofire

/// Main app object.
/// Contais flobal information for the **GeoConfess** app.
@UIApplicationMain
final class App: UIResponder, UIApplicationDelegate {

	// MARK: - Server Information
	
	/// Our **RESTful** server/backend URL.
	static let serverURL = NSURL(string: "https://geoconfess.herokuapp.com")!
	
	/// URL for server/backend API.
	static let serverAPI = "\(App.serverURL)/api/v1"
	
	// AWS S3.
	static let cognitoPoolID = "eu-west-1:931c05b1-94ee-40a4-a691-6bce6b3edbb8"
	
	/// Google Maps key.
	///
	/// 	API key for bundle id `com.ktotv.geoconfess`. This key
	/// was generated using KTO's Google Developer account.
	///
	/// Back to Paulo's key.
	static let googleMapsApiKey = "AIzaSyCVCVu4E5UpoZcCfapDrJl4H7HfBNDt74c"

	// MARK: - App Lifecyle
	
	/// Returns the app's singleton instance.
	static var instance: App {
		return UIApplication.sharedApplication().delegate as! App
	}
	
	var state: UIApplicationState {
		return UIApplication.sharedApplication().applicationState
	}

	var window: UIWindow?

	func application(
		application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		
		log("Did Finish Launching With Options (state: \(application.applicationState))")
		logBundleInformation()
		initConfiguration()
		initNetworkReachability {
			self.initGoogleMaps()
			self.initAmazonWebServices()
			self.initPushNotifications(application)
			self.isInitialized = true
		}
		
		return true
	}
	
	private(set) var isInitialized: Bool = false

	private func logBundleInformation() {
		if let simulatorPath = NSBundle.mainBundle().simulatorPath {
			log("Simulator path: \(simulatorPath.stringByShrinkingPath)")
			let bundlePath = NSBundle.mainBundle().bundlePathFromSimulator!
			log("Bundle path: \(bundlePath.stringByShrinkingPath)")
			let tmpPath = NSBundle.mainBundle().temporaryDirectoryFromSimulator!
			log("Temp path: \(tmpPath.stringByShrinkingPath)")
		}
	}

	/// Restart any tasks that were paused (or not yet started) while the
	/// application was inactive. If the application was previously in the
	/// background optionally refresh the user interface.
	func applicationDidBecomeActive(application: UIApplication) {
		log("Application Did Become Active (state: \(application.applicationState))")
	}
	
	/// Sent when the application is about to move from active to inactive state.
	/// This can occur for certain types of temporary interruptions
	/// (such as an incoming phone call or SMS message) or when the user quits
	/// the application and it begins the transition to the background state.
	///
	/// Use this method to pause ongoing tasks, disable timers, 
	/// and throttle down OpenGL ES frame rates. Games should use this method to 
	/// pause the game.
    func applicationWillResignActive(application: UIApplication) {
		log("Application Will Resign Active (state: \(application.applicationState))")
    }

	/// Use this method to release shared resources, save user data, invalidate timers, 
	/// and store enough application state information to restore your application 
	/// to its current state in case it is terminated later.
	///
	/// If your application supports background execution, this method is called 
	/// instead of applicationWillTerminate: when the user quits.
    func applicationDidEnterBackground(application: UIApplication) {
		log("Application Did Enter Background (state: \(application.applicationState))")
		if let user = User.current {
			user.applicationDidEnterBackground()
		}
    }

	/// Called as part of the transition from the background to the inactive 
	/// state; here you can undo many of the changes made on entering the background.
    func applicationWillEnterForeground(application: UIApplication) {
		log("Application Will Enter Foreground (state: \(application.applicationState))")
		if let user = User.current {
			user.applicationWillEnterForeground()
		}
    }

	/// Called when the application is about to terminate.
	/// Save data if appropriate. See also applicationDidEnterBackground:.
    func applicationWillTerminate(application: UIApplication) {
		log("Application Will Terminate (state: \(application.applicationState))")
	}
	
	func applicationDidReceiveMemoryWarning(application: UIApplication) {
		log("Memory WARNING received")
		CLGeocoder.removeAllCachedRequests()
	}

	// MARK: - Services
	
	private func initGoogleMaps() {
		GMSServices.provideAPIKey(App.googleMapsApiKey)
	}
	
	private func initAmazonWebServices() {
		AWSLogger.defaultLogger().logLevel = .Info
		
		let credentials = AWSStaticCredentialsProvider(
			accessKey: "AKIAJTOJQ4EE6SHXMCVA",
			secretKey: "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")
		
		let configuration = AWSServiceConfiguration(
			region: AWSRegionType.EUWest1,
			credentialsProvider: credentials)
		
		let serviceManager = AWSServiceManager.defaultServiceManager()
		serviceManager.defaultServiceConfiguration = configuration
	}
	
	// MARK: - Push Notifications

	private(set) var pushNotificationService: FCMPushNotificationService!

	private func initPushNotifications(application: UIApplication) {
		let notificationTypes: UIUserNotificationType = [.Alert, .Badge,	.Sound]
		let pushNotificationSettings = UIUserNotificationSettings(
			forTypes: notificationTypes, categories: nil)
		application.registerUserNotificationSettings(pushNotificationSettings)
		pushNotificationService = FCMPushNotificationService()
	}
	
    func application(
		application: UIApplication,
		didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		
		log("Did Register For Remote Notifications With Device Token:")
		print("Device token: \(deviceToken)")
		pushNotificationService.deviceToken = deviceToken
    }
    
    func application(
		application: UIApplication,
		didFailedToRegisterForRemoteNotificationsWithDeviceToken error: NSError) {
		
		logError("Did Failed To Register For Remote Notifications: \(error)")
    }
    
    func application(
		application: UIApplication,
		didRegisterUserNotificationSettings notificationSettings:
		UIUserNotificationSettings) {
		/* empty */
    }

	/// Tells the app that a remote notification arrived with data to be fetched.
	///
	/// The `userInfo` payload parameter ollows this schema:
	///
	///     {
	///         "aps": {
	///             "content-available" : "1",
	///             "alert" : "<message text>",
	///             "sound" : "default"
	///          },
	///         "gcm.message_id": null,
	///         "gcm.notification.data": {
	///             "model": "MeetRequest|Message"
	///             "action": "received",
	///             "id": <notificationable id>,
	///             "notification_id": 123,
	///             "user_id": 123,
	///         }
	///     }
	///
	/// For a priest availability confirmation, the payload changes to:
	///
	///     "gcm.notification.data": {
	///         "name":  "<spot name>",
	///         "model": "Recurrence"
	///         "action": "availability",
	///         "id": <recurrence id which starts in one hour>,
	///         "notification_id": null,
	///         "user_id": 123,
	///     }
	///
	/// About Local and Remote Notifications: https://goo.gl/wnIfJj
	func application(
		application: UIApplication,
		didReceiveRemoteNotification userInfo: [NSObject : AnyObject],
		fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		
		let initialTime = CACurrentMediaTime()
		let jsonPayload = jsonFromRemoteNotification(userInfo)
		let sizeInBytes = (try! jsonPayload.rawData()).length
		
		log("Did Receive Remote Notification (state: \(application.applicationState))")
		print("APNS payload:\n\(jsonPayload)")
		print("Payload size: \(sizeInBytes) bytes (maximum size is 4096 bytes)")

		// As soon as we finish processing the notification, *we* must call
		// the `completionHandler` parameter or the app will be terminated.
		// We have up to 30 seconds of wall-clock time to process the
		// notification and call the specified completion handler block.
		let data = jsonPayload["gcm.notification.data"].dictionary!
		let notificationForUser = data["user_id"]!.resourceID!
		guard let user = User.current else {
			log("Push notification ignored since no user is logged-in")
			return
		}
		guard user.id == notificationForUser else {
			log("Push notification NOT for this user -- for \(notificationForUser)")
			return
		}
		guard let id = data["notification_id"]?.resourceID else {
			let notification = PriestAvailabilityNotification(
				spotName: data["name"]!.string!,
				recurrenceID: data["id"]!.resourceID!,
				forPriest: user as! Priest)
			user.notificationManager.didReceivePushNotification(notification) {
				result in
				switch result {
				case .Success:
					completionHandler(.NoData)
				case .Failure(let error):
					logError("Push notification processing failed: \(error)")
					completionHandler(.Failed)
				}
			}
			return
		}
		let action = Notification.Action(rawValue: data["action"]!.string!)!
		user.notificationManager.didReceivePushNotification(id, with: action) {
			result in
			let elapsedTime = String(format: "%.1f", CACurrentMediaTime() - initialTime)
			log("Remote notification processing time: \(elapsedTime) seconds (max 30)")
			switch result {
			case .Success(let notification):
				assert(notification.id == id)
				completionHandler(.NewData)
			case .Failure(let error):
				logError("Push notification processing failed: \(error)")
				completionHandler(.Failed)
			}
		}
    }
	
	private func jsonFromRemoteNotification(userInfo: [NSObject : AnyObject]) -> JSON {
		var payload = [String: JSON]()
		for (key, value) in userInfo {
			let jsonValue: JSON
			if let value = value as? String {
				let jsonEncodedString = value.dataUsingEncoding(
					NSUTF8StringEncoding, allowLossyConversion: false)!
				jsonValue = JSON(data: jsonEncodedString)
			} else {
				jsonValue = JSON(value)
			}
			payload[key as! String] = jsonValue
		}
		return JSON(payload)
	}
	
	// MARK: - App Configuration
	
	enum Configuration: String, CustomStringConvertible {
		
		/// The *official* config used in production.
		case Distribution
		
		/// The hacked/faster config used during development/tests.
		case Test
		
		var plistName: String {
			return "GeoConfess-\(self)"
		}
		
		var description: String {
			return rawValue
		}
	}
	
	var configuration: Configuration = App.configurationAtAppLaunch() {
		didSet {
			let defaults = NSUserDefaults.standardUserDefaults()
			defaults.setObject(configuration.rawValue, forKey: App.lastConfigKey)
			properties = loadPropertiesFor(configuration)
			notifyObservers {
				$0.applicationDidUpdateConfiguration(self.configuration)
			}
			let configName = configuration.description.uppercaseString
			log("\(configName) configuration now active")
		}
	}

	/// The initial configuration is based on the last one used.
	private func initConfiguration() {
		self.properties = loadPropertiesFor(configuration)
		log("Initial config: \(configuration)")
	}
	
	private static let lastConfigKey = "GeoConfessLastConfig"
	
	private static func configurationAtAppLaunch() -> Configuration {
		#if DEBUG
			let defaults = NSUserDefaults.standardUserDefaults()
			if let lastConfig = defaults.stringForKey(App.lastConfigKey) {
				return Configuration(rawValue: lastConfig) ?? .Distribution
			} else {
				return .Distribution
			}
		#else
			return .Distribution
		#endif
	}

	/// Returns the current GeoConfess's *properties list*.
	var properties: [String: AnyObject]!
	
	@warn_unused_result
	private func loadPropertiesFor(config: Configuration) -> [String: AnyObject] {
		let bundle = NSBundle.mainBundle()
		let plistPath = bundle.pathForResource(config.plistName, ofType: "plist")!
		let plist = NSDictionary(contentsOfFile: plistPath)
		return plist as! [String: AnyObject]
	}
	
	/// The actual type is `ObservableObject<AppObserver>`.
	private let appObservers = ObserverSet()
	
	func addObserver(observer: AppObserver) {
		appObservers.addObserver(observer)
	}
	
	func removeObserver(observer: AppObserver) {
		appObservers.removeObserver(observer)
	}
	
	private func notifyObservers(notify: AppObserver -> Void) {
		appObservers.notifyObservers {
			notify($0 as! AppObserver)
		}
	}

	// MARK: - Network Reachability

	private var networkReachability: NetworkReachabilityManager!
	
	private func initNetworkReachability(initServices: () -> Void) {
		let serverHost = App.serverURL.host!
		var initServicesCalled = false
		networkReachability = NetworkReachabilityManager(host: serverHost)
		networkReachability.listener = {
			status in
			log("Network reachability status changed: \(status)")
			if status.isReachable && !initServicesCalled {
				initServices()
				initServicesCalled = true
			}
			let topVC = AppNavigationController.current?.topViewController
			(topVC as? AppViewController)?.networkReachabilityStatusDidChange(status)
		}
		networkReachability.startListening()
	}
	
	/// Whether the network is currently reachable.
	/// Also returns true if reachability is *unknown*.
	var isNetworkReachable: Bool {
		switch networkReachability.networkReachabilityStatus {
		case .Unknown, .Reachable:
			return true
		case .NotReachable:
			return false
		}
	}
	
	// MARK: - App Metadata
	
	var version: String {
		let mainBundle = NSBundle.mainBundle()
		return mainBundle.infoDictionary!["CFBundleShortVersionString"] as! String
	}

	var buildNumber: UInt {
		let mainBundle = NSBundle.mainBundle()
		return UInt(mainBundle.infoDictionary!["CFBundleVersion"] as! String)!
	}

	// MARK: - UI Colors
	
	/// This is the *main* color used across the UI.
	/// It resembles the [Carmine Pink](http://name-of-color.com/#EB4C42) color.
	static let tintColor = UIColor(red: 233/255, green: 72/255, blue: 84/255, alpha: 1)
}

// MARK: - Network Reachability

/// Defines the various states of network reachability.
///
/// - `Unknown`:      It is unknown whether the network is reachable.
/// - `NotReachable`: The network is not reachable.
/// - `Reachable`:    The network is reachable over WiFi or WWAN connection.
typealias NetworkReachabilityStatus =
	NetworkReachabilityManager.NetworkReachabilityStatus

extension NetworkReachabilityStatus: CustomStringConvertible {
	
	/// Whether the network is currently reachable.
	var isReachable: Bool {
		switch self {
		case .Unknown, .NotReachable:
			return false
		case .Reachable:
			return true
		}
	}
	
	public var description: String {
		switch self {
		case .Unknown:
			return "Unknown"
		case .NotReachable:
			return "NotReachable"
		case .Reachable(let connectionType):
			switch connectionType {
			case .EthernetOrWiFi:
				return "Reachable(WiFi)"
			case .WWAN:
				return "Reachable(WWAN)"
			}
		}
	}
}

// MARK: - App Observer

/// Observer for top-level app events.
protocol AppObserver: Observer {
	
	func applicationDidUpdateConfiguration(config: App.Configuration)
}

// MARK: - UIKit Extensions

extension UITextField {
	
	var isEmpty: Bool {
		return text == nil || text!.trimWhitespaces() == ""
	}
}

extension UIButton {
	
	static var enabledColor: UIColor {
		return UIColor(red: 237/255, green: 95/255, blue: 102/255, alpha: 1.0)
	}
	
	static var disabledColor: UIColor {
		return UIColor.lightGrayColor()
	}
}

// MARK: - iPhone Resolutions

/// A known iPhone model.
enum iPhoneModel {
	case iPhone4, iPhone5
	case iPhone6, iPhone6Plus
	case futureModel
	
	static let models: [iPhoneModel] = [
		.iPhone4, .iPhone5, .iPhone6, .iPhone6Plus
	]
	
	/// iPhone screen resolution in *points*.
	/// Yes, this is used for layout hacks!
	var screenResolution: CGSize {
		switch self {
		case .iPhone4:
			return CGSize(width: 320, height: 480)
		case .iPhone5:
			return CGSize(width: 320, height: 568)
		case .iPhone6:
			return CGSize(width: 375, height: 667)
		case .iPhone6Plus:
			return CGSize(width: 414, height: 736)
		case .futureModel:
			preconditionFailure()
		}
	}
}

extension UIViewController {
	
	var iPhoneModel: GeoConfess.iPhoneModel {
		let screenSize = UIScreen.mainScreen().bounds.size
		for iPhone in GeoConfess.iPhoneModel.models {
			if iPhone.screenResolution == screenSize {
				return iPhone
			}
		}
		return .futureModel
	}
	
	func convertVerticalConstantFromiPhone6(constraint: NSLayoutConstraint) {
		let screenHeight = UIScreen.mainScreen().bounds.height
		let iPhone6Height = GeoConfess.iPhoneModel.iPhone6.screenResolution.height
		constraint.constant = constraint.constant * screenHeight/iPhone6Height
	}
}

// MARK: - CoreLocation Extensions

private var reverseGeocodeCache = [CLLocationCoordinate2D: CLPlacemark]()

extension CLGeocoder {
	
	/// A reverse-geocoding request for the specified location with *caching* support.
	func cachedReverseGeocodeLocation(location: CLLocation,
	                                  completionHandler: CLGeocodeCompletionHandler) {
		preconditionIsMainQueue()
		if let cachedPlacemark = reverseGeocodeCache[location.coordinate] {
			let stringLocation = location.coordinate.shortDescription
			log("Reverse geocoding cache hit for location \(stringLocation)")
			dispatch_async(dispatch_get_main_queue()) {
				return completionHandler([cachedPlacemark], nil)
			}
			return
		}
		let geocoder = CLGeocoder()
		geocoder.reverseGeocodeLocation(location) {
			placemarks, error in
			guard let placemark = placemarks?.first else {
				completionHandler(nil, error)
				return
			}
			reverseGeocodeCache[location.coordinate] = placemark
			return completionHandler([placemark], nil)
		}
	}
	
	private static func removeAllCachedRequests() {
		reverseGeocodeCache.removeAll()
	}
}
