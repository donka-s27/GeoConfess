//
//  AppViewController.swift
//  GeoConfess
//
//  Created  by Dan Markov on January 31, 2016.
//  Reviewed by Donka Simeonov on May 18, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import MIBadgeButton_Swift

/// This is the custom **navigation view controller** used by the app.
@IBDesignable
final class AppNavigationController: UINavigationController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	/// The app's custom navigation controller.
	/// This property contains the nearest ancestor in the view
	/// controller hierarchy that is a navigation controller.
	static weak private(set) var current: AppNavigationController!
	
	/// The custom toolbar associated with the navigation controller.
	override var toolbar: AppToolbar! {
		guard let toolbar = super.toolbar else { return nil }
		return toolbar as! AppToolbar
	}
	
	/// The image used as the current view controller **title**.
	@IBInspectable
	var logo: UIImage!
}

// MARK: -

/// The custom toolbar used by all main screens.
@IBDesignable
class AppToolbar: UIToolbar {
	
	/// The toolbar custom height.
	/// The iOS toolbar default height is `44`.
	@IBInspectable
	var height: CGFloat = 44
	
	/// Asks the view to calculate and return the
	/// size that best fits the specified size.
	override func sizeThatFits(size: CGSize) -> CGSize {
		var newSize = super.sizeThatFits(size)
		newSize.height = height
		return newSize
	}
}

// MARK: -

/// Superclass for *all* view controllers used by the app.
/// This controller instance will be embedded 
/// inside our custom `AppNavigationController`.
class AppViewController: UIViewController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setLogoAsTitle()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		AppNavigationController.current = navigationController!
		registerKeyboardNotifications()
		setBackButton()
		updateTestConfigLabel()
		
		if !App.instance.isNetworkReachable {
			if self is LoginViewController == false {
				self.presentLoginViewController()
			}
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		AppNavigationController.current = nil
		unregisterKeyboardNotifications()
	}

	/// The app's custom navigation controller.
	override var navigationController: AppNavigationController! {
		return super.navigationController as? AppNavigationController
	}
	
	// MARK: Network Reachability
	
	func networkReachabilityStatusDidChange(status: NetworkReachabilityStatus) {
		switch status {
		case .NotReachable:
			presentLoginViewController()
		case .Reachable, .Unknown:
			break
		}
	}

	/// Presents the *login* view controller modally.
	func presentLoginViewController() {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let loginVC = storyboard.instantiateViewControllerWithIdentifier("Login")
		if let user = User.current {
			showProgressHUD()
			user.logoutInBackground {
				result in
				self.hideProgressHUD()
				self.presentViewController(loginVC, animated: true, completion: nil)
			}
		} else {
			presentViewController(loginVC, animated: true, completion: nil)
		}
	}
	
	// MARK: App Logo
	
	private static var isFirstViewController = true
	private var testConfigLabel: UILabel!

	/// Sets the app's logo as this view controller **title**.
	/// As opposed to its back button, this is *not*
	/// based on the view controller current state.
	///
	/// 	We use a *hacked* title to indicate that a
	/// **development config** is currently active.
	private func setLogoAsTitle() {
		testConfigLabel = createTestModeLabel()
		let logoView  = createLogoView()
		let titleView = UIView()
		// We use the title view just as an anchor to the *center*
		// of the navigation bar (ie, the title view size will be ignored).
		let constraints: [NSLayoutConstraint] = [
			// Logo image at center XY.
			equalsConstraint(
				item:   logoView,  attribute: .CenterX,
				toItem: titleView, attribute: .CenterX),
			equalsConstraint(
				item:   logoView,  attribute: .CenterY,
				toItem: titleView, attribute: .CenterY, constant: -3),
			// Test label at bottom right.
			equalsConstraint(
				item:   testConfigLabel, attribute: .Top,
				toItem: logoView,      attribute: .Bottom, constant: 0.55),
			equalsConstraint(
				item:   testConfigLabel, attribute: .Trailing,
				toItem: logoView,      attribute: .Trailing)
		]
		titleView.addSubview(logoView)
		titleView.addSubview(testConfigLabel)
		titleView.addConstraints(constraints)
		navigationItem.titleView = titleView
		#if DEBUG
			addSwitchConfigGestureRecognizer(titleView)
		#endif
		
		// Hack to ensure the title view's size will not be zero.
		// A zero-ish superview may *not* send touch events down the view hierarchy.
		logoView.layoutIfNeeded()
		testConfigLabel.layoutIfNeeded()
		let logoSize = logoView.frame.size
		let titleHeight = logoSize.height + testConfigLabel.frame.size.height + 2.0
		titleView.frame.size = CGSize(width: logoSize.width, height: titleHeight)
		//titleView.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
		
		// Smooth animation for first view controller.
		if AppViewController.isFirstViewController {
			logoView.alpha = 0
			UIView.animateWithDuration(1.90,
				animations: {
					logoView.alpha = 1
				},
				completion: {
					finished  in
					/* empty */
				}
			)
			AppViewController.isFirstViewController = false
		}
	}

	private func createLogoView() -> UIView {
		let logoImage: UIImage = navigationController.logo!
		let logoAspectRatio = logoImage.size.width / logoImage.size.height
		let logoView = UIImageView(image: logoImage)
		
		let logoConstraints: [NSLayoutConstraint] = [
			equalsConstraint(
				item: logoView, attribute: .Width, value: 120),
			equalsConstraint(
				item:   logoView, attribute: .Width,
				toItem: logoView, attribute: .Height, multiplier: logoAspectRatio)
		]
		logoView.translatesAutoresizingMaskIntoConstraints = false
		logoView.addConstraints(logoConstraints)
		return logoView
	}
	
	private func addSwitchConfigGestureRecognizer(titleView: UIView) {
		let switchConfigGesture = UITapGestureRecognizer()
		switchConfigGesture.numberOfTapsRequired = 3
		switchConfigGesture.numberOfTouchesRequired = 1
		switchConfigGesture.addTarget(self, action: #selector(self.titleTapDetected(_:)))
		titleView.addGestureRecognizer(switchConfigGesture)
		titleView.userInteractionEnabled = true
	}
	
	@objc private func titleTapDetected(sender: UITapGestureRecognizer) {
		guard sender.state == .Ended else { return }
		
		let testLabelAlpha: CGFloat
		switch App.instance.configuration {
		case .Distribution:
			App.instance.configuration = .Test
			testLabelAlpha = 1.0
		case .Test:
			App.instance.configuration = .Distribution
			testLabelAlpha = 0.0
		}
		UIView.animateWithDuration(0.35) {
			self.testConfigLabel.alpha = testLabelAlpha
		}
	}
	
	private func createTestModeLabel() -> UILabel {
		let testLabel = UILabel()
		testLabel.text = "test"
		
		let navigationBar = navigationController.navigationBar
		if navigationBar.barTintColor!.equalsRed(1, green: 1, blue: 1) {
			testLabel.textColor = UIColor(white: 0, alpha: 0.40)
		} else {
			testLabel.textColor = navigationBar.tintColor.colorWithAlphaComponent(0.80)
		}
		testLabel.font = UIFont(name: "Menlo-Bold", size: 10.8)!
		testLabel.sizeToFit()
		testLabel.translatesAutoresizingMaskIntoConstraints = false

		return testLabel
	}

	private func updateTestConfigLabel() {
		switch App.instance.configuration {
		case .Distribution:
			testConfigLabel.alpha = 0.0
		case .Test:
			testConfigLabel.alpha = 1.0
		}
	}

	// MARK: Back Button
	
	/// Sets this view controller custom **back button**.
	/// As opposed to its title, this *is* based on the
	/// view controller current state (eg, nav stack size).
	///
	/// When this view controller is immediately below the top controller in
	/// the stack, the navigation controller derives the back button for the
	/// navigation bar from *this* view controller's `navigationItem` property.
	private func setBackButton() {
		navigationItem.backBarButtonItem = UIBarButtonItem(
			title: "", style: .Plain, target: nil, action: nil)
	}

	// MARK: Tracking First Responder
	
	/// Ensures touches outside the specified views will
	/// result in view resigning first responder status 
	/// (eg, *closes* keyboard if showing).
	func resignFirstResponderWithOuterTouches(views: UIView...) {
		let viewRefs = views.map { Weak($0) }
		resignFirstResponders.unionInPlace(viewRefs)
	}
	
	private var resignFirstResponders = Set<Weak<UIView>>()
	
	override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
		for viewRef in resignFirstResponders {
			viewRef.object?.resignFirstResponder()
		}
	}
	
	// MARK: Keyboard Events
	
	private func registerKeyboardNotifications() {
		let notificationCenter = NSNotificationCenter.defaultCenter()
		
		notificationCenter.addObserver(
			self,
			selector: #selector(AppViewController.keyboardWillShowNotification(_:)),
			name: UIKeyboardWillShowNotification, object: nil)

		notificationCenter.addObserver(
			self,
			selector: #selector(AppViewController.keyboardDidShowNotification(_:)),
			name: UIKeyboardDidShowNotification, object: nil)

		notificationCenter.addObserver(
			self,
			selector: #selector(AppViewController.keyboardWillHideNotification(_:)),
			name: UIKeyboardWillHideNotification, object: nil)

		notificationCenter.addObserver(
			self,
			selector: #selector(AppViewController.keyboardDidHideNotification(_:)),
			name: UIKeyboardDidHideNotification, object: nil)
	}

	private func unregisterKeyboardNotifications() {
		let notificationCenter = NSNotificationCenter.defaultCenter()
		
		notificationCenter.removeObserver(
			self, name: UIKeyboardWillShowNotification, object: nil)

		notificationCenter.removeObserver(
			self, name: UIKeyboardDidShowNotification, object: nil)

		notificationCenter.removeObserver(
			self, name: UIKeyboardWillHideNotification, object: nil)
		
		notificationCenter.removeObserver(
			self, name: UIKeyboardDidShowNotification, object: nil)
	}
	
	private func keyboardFrameAt(notification: NSNotification) -> CGRect {
		let userInfo = notification.userInfo!
		let keyboardFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue
		return keyboardFrame.CGRectValue()
	}
	
	@objc private func keyboardWillShowNotification(notification: NSNotification) {
		keyboardWillShow(keyboardFrameAt(notification))
	}

	@objc private func keyboardDidShowNotification(notification: NSNotification) {
		keyboardDidShow(keyboardFrameAt(notification))
	}

	@objc private func keyboardWillHideNotification(notification: NSNotification) {
		keyboardWillHide(keyboardFrameAt(notification))
	}

	@objc private func keyboardDidHideNotification(notification: NSNotification) {
		keyboardDidHide(keyboardFrameAt(notification))
	}
	
	/// Called immediately *prior* to the display of the keyboard.
	///
	/// - Parameter keyboardFrame: a CGRect that identifies
	/// 		the end frame of the keyboard in **screen coordinates**.
	func keyboardWillShow(keyboardFrame: CGRect) {
		/* empty */
	}

	/// Called immediately *after* to the display of the keyboard.
	///
	/// - Parameter keyboardFrame: a CGRect that identifies
	/// 		the end frame of the keyboard in **screen coordinates**.
	func keyboardDidShow(keyboardFrame: CGRect) {
		/* empty */
	}

	/// Called immediately *prior* to the dismissal of the keyboard.
	///
	/// - Parameter keyboardFrame: a CGRect that identifies
	/// 		the end frame of the keyboard in **screen coordinates**.
	func keyboardWillHide(keyboardFrame: CGRect) {
		/* empty */
	}

	/// Called immediately *after* to the dismissal of the keyboard.
	///
	/// - Parameter keyboardFrame: a CGRect that identifies
	/// 		the end frame of the keyboard in **screen coordinates**.
	func keyboardDidHide(keyboardFrame: CGRect) {
		/* empty */
	}
}

// MARK: -

/// Adds support for an optional toolbar to `AppViewController` objects.
/// The implementation is fully based on the navigation controller's *built-in* toolbar.
class AppViewControllerWithToolbar: AppViewController,
PriestObserver, NotificationObserver {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setToolbarButtons()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		let user = User.current!
		
		switch user.role {
		case .Admin, .Penitent:
			break
		case .Priest:
			availableToMeetButton.hidden = false
			let priest = User.currentPriest!
			self.priest(priest, didSetAvailableToMeet: priest.availableToMeet)
		}
		user.addObserver(self)
		
		setNotificationsBadge(user.notificationManager.notifications)
		user.notificationManager.addObserver(self)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Kiils observers if user still exits.
		if let user = User.current {
			user.removeObserver(self)
			user.notificationManager.removeObserver(self)
		}
	}
	
	func priest(priest: Priest, didSetAvailableToMeet availableToMeet: Bool) {
		let image = availableToMeet ? availableButtonImage : unavailableButtonImage
		availableToMeetButton.setImage(image, forState: .Normal)
	}
	
	func user(user: User, didUpdateLocation location: CLLocation) {
		/* empty */
	}
	
	func user(user: User, didUpdateNearbySpots spots: Set<Spot>) {
		/* empty */
	}
	
	// MARK: Location Tracking
	
	func userDidDenyLocalizationTracking(user: User) {
		showLocalizationTrackingDeniedAlert {
			self.presentLoginViewController()
		}
	}
	
	// MARK: Notification Badge
	
	func notificationManager(manager: NotificationManager,
	                         didAddNotifications notifications: [Notification]) {
		setNotificationsBadge(manager.notifications)
	}
	
	func notificationManager(manager: NotificationManager,
	                         didDeleteNotifications notifications: [Notification]) {
		setNotificationsBadge(manager.notifications)
	}
	
	private func setNotificationsBadge(notifications: [Notification]) {
		let unread = notifications.userLevelNotifications().unreadCount
		if unread > 0 {
			notificationsRedBadge.badgeString = "\(unread)"
		} else {
			notificationsRedBadge.badgeString = ""
		}
		UIApplication.sharedApplication().applicationIconBadgeNumber = unread
	}
	
	// MARK: Push Notifications
	
	func notificationManager(manager: NotificationManager,
	                         didAddMessages messages: [Message]) {
		/* empty */
	}
	
	func notificationManager(manager: NotificationManager,
	                         didReceivePushNotification notification: Notification) {
		// Only present view controller if user actually tapped the
		//  push notification (ie, app is coming back from background).
		guard App.instance.state == .Inactive else { return }
		NotificationsViewController.pushViewControllerForPushNotification(notification)
	}
	
	func notificationManager(manager: NotificationManager, didReceivePushNotification
	                         notification: PriestAvailabilityNotification) {
		// Only present confirmation alert if app running.
		let appState = App.instance.state
		guard appState == .Inactive || appState == .Active else { return }
		var message = "Confirmez votre disponibilité pour confesser"
		if let spot = notification.spot {
			let startAt = spot.recurrence!.startAt.displayDescription
			let stopAt  = spot.recurrence!.stopAt.displayDescription
			message += " (\(startAt)-\(stopAt))"
		}
		showYesNoAlert(
			title: "\(notification.spotName)",
			message: message,
			yes: {
				notification.confirmAvailability {
					result in
					switch result {
					case .Success:
						break
					case .Failure(let error):
						logError("Confirm availability failed: \(error)")
						self.showAlertForError(error)
					}
				}
			},
			no: {
				/* empty */
			}
		)
	}

	// MARK: Toolbar Buttons
	
	private var notificationsButtonItem: UIBarButtonItem!
	private var notificationsRedBadge: MIBadgeButton!
	
	private var availableToMeetButtonItem: UIBarButtonItem!
	private let availableButtonImage   = UIImage(named: "Disponible Button")!
	private let unavailableButtonImage = UIImage(named: "Indisponible Button")!
	
	var notificationsButton: UIButton {
		return notificationsButtonItem.buttonView
	}
	
	var availableToMeetButton: UIButton! {
		return availableToMeetButtonItem?.buttonView
	}

	/// Sets all 3 toolbar buttons.
	/// This code *only* runs if an actual `AppToolbar` is available.
	private func setToolbarButtons() {
		guard let toolbar = navigationController.toolbar else { return }
		
        notificationsRedBadge = MIBadgeButton()
		notificationsRedBadge.badgeString = " "
		notificationsRedBadge.badgeEdgeInsets = UIEdgeInsetsMake(10, 10, 0, 10)
        notificationsRedBadge.badgeTextColor = UIColor.whiteColor()
        notificationsRedBadge.badgeBackgroundColor = UIColor.redColor()
		
		let notificationImage = UIImage(named: "Notification Icon")!
		notificationsButtonItem = toolbar.highlightedBarButtonWithImage(
			notificationImage, width: 30, hightlightIntensity: 0.4,
			usingButton: notificationsRedBadge)
		notificationsButton.setTargetForTap(
			self, #selector(self.notificatioButtonTapped(_:)))
		
		let space = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace)
		let fixedSpace = UIBarButtonItem(barButtonSystemItem: .FixedSpace, width: 30)
		
		let items: [UIBarButtonItem]
		switch User.current.role {
		case .Admin, .Penitent:
			items = [space, notificationsButtonItem, space]
		case .Priest:
			availableToMeetButtonItem = toolbar.barButtonWithImage(
				unavailableButtonImage, width: 95)
			availableToMeetButton.setTargetForTap(
				self, #selector(self.availableToMeetButtonTapped(_:)))
			items = [
				space, notificationsButtonItem, space,
				availableToMeetButtonItem,
				space, fixedSpace, space
			]
		}
		setToolbarItems(items, animated: false)
		
	}
	
	func notificatioButtonTapped(button: UIButton) {
		let notificationsVC = NotificationsViewController.instantiateViewController()
		navigationController.pushViewController(notificationsVC, animated: true)
	}
	
	func availableToMeetButtonTapped(buttton: UIButton) {
		let priest = User.currentPriest!
		if !priest.availableToMeet {
			let spotsVC = PriestSpotsViewController.instantiateViewController()
			navigationController.pushViewController(spotsVC, animated: true)
		} else {
			priest.setAvailableToMeet(false) {
				result in
				switch result {
				case .Success:
					self.showAlert(
						title: "Géolocalisation",
						message:
						"Géolocalisation désactivée. Merci d'avoir utilisé GeoConfess!")
				case .Failure(let error):
					preconditionFailure("setAvailableToMeet failed: \(error)")
				}
			}
		}
	}
}

// MARK: - BarView Protocol

/// Common interface for `UINavigationBar` and `UIToolbar` objects.
protocol BarView {
	
	/// Foreground color.
	var tintColor: UIColor! { get }
	
	/// Background color.
	var barTintColor: UIColor? { get }
}	

extension BarView {
	
	/// Creates a *standard* button for bars.
	func barButtonWithImage(buttonImage: UIImage, width: CGFloat) -> UIBarButtonItem {
		let button = UIButton(type: .Custom)
		button.setImage(buttonImage, forState: .Normal)
		
		let imageAspectRatio = buttonImage.size.width / buttonImage.size.height
		button.frame.size = CGSize(width: width, height: width/imageAspectRatio)
		return UIBarButtonItem(customView: button)
	}
	
	/// Creates a *standard* button for bars with hightlight support.
	func highlightedBarButtonWithImage(buttonImage: UIImage, width: CGFloat,
	                                   hightlightIntensity: CGFloat = 0.7,
	                                   usingButton: UIButton? = nil)
										-> UIBarButtonItem {
		precondition(buttonImage.renderingMode == .AlwaysTemplate)
		let button = usingButton ?? UIButton(type: .Custom)
		
		let barTintColor = self.barTintColor ?? UIColor.whiteColor()
		let highlightedColor = barTintColor.blendedColorWith(
			tintColor, usingWeight: hightlightIntensity)
		let highlightedImage = buttonImage.tintedImageWithColor(highlightedColor)
		
		button.setImage(buttonImage, forState: .Normal)
		button.setImage(highlightedImage, forState: .Highlighted)
		
		let imageAspectRatio = buttonImage.size.width / buttonImage.size.height
		button.frame.size = CGSize(width: width, height: width/imageAspectRatio)
		return UIBarButtonItem(customView: button)
	}
}

/// Conforming `UINavigationBar` class to `BarView` protocol.
extension UINavigationBar: BarView {
	/* empty */
}

/// Conforming `UIToolbar` class to `BarView` protocol.
extension UIToolbar: BarView {
	/* empty */
}

// MARK: - UIBarButtonItem Extensions

/// Lightweight support for `UIButton` embedded in `UIBarButtonItem` instance.
extension UIBarButtonItem {
	
	var buttonView: UIButton! {
		return customView as? UIButton
	}
	
	var hidden: Bool {
		get {
			return customView!.hidden
		}
		set {
			customView!.hidden = newValue
		}
	}
}
