/*
The MIT License (MIT)

Copyright (c) 2014-2016 Dan, Antoine Berton

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall
be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

//
//  Utilities.swift
//  GeoConfess
//
//  Created by Donka on July 10, 2015.
//

import Foundation
import GoogleMaps
import MapKit
import SwiftyJSON
import MBProgressHUD

// MARK: - Strings

private let whitespaces = NSCharacterSet.whitespaceAndNewlineCharacterSet()

extension String {

	/// Removes whitespaces from both ends of the string.
	func trimWhitespaces() -> String {
		return self.stringByTrimmingCharactersInSet(whitespaces)
	}
	
	var stringWithUppercaseFirstCharacter: String {
		guard !self.isEmpty else { return "" }
		let firstChar = self[startIndex..<startIndex.advancedBy(1)].uppercaseString
		return firstChar + self[startIndex.advancedBy(1)..<endIndex]
	}
}

// MARK: - Files & Directories

extension String {
	
	/// A new string made by deleting the extension
	/// (if any, and only the last) from the receiver.
	var stringByDeletingPathExtension: String {
		let string: NSString = self
		return string.stringByDeletingPathExtension
	}

	/// Returns a new string made by appending to the receiver a given string.
	func stringByAppendingPathComponent(str: String) -> String {
		let string: NSString = self
		return string.stringByAppendingPathComponent(str)
	}
	
	/// The last path component.
	/// This property contains the last path component. For example:
	///
	/// 	 /tmp/scratch.tiff ➞ scratch.tiff
	/// 	 /tmp/scratch ➞ scratch
	/// 	 /tmp/ ➞ tmp
	///
	var lastPathComponent: String {
		let string: NSString = self
		return string.lastPathComponent
	}
	
	/// The file-system path components of the receiver.
	/// For example:
	///
	/// 	 tmp/scratch.tiff ➞ ["tmp", "scratch.tiff"]
	/// 	 /tmp/scratch.tiff ➞ ["/", "tmp", "scratch.tiff"]
	///
	var pathComponents: [String] {
		let string: NSString = self
		return string.pathComponents
	}
	
	/// A new string made by standardizing path components from the receiver.
	var stringByStandardizingPath: String {
		let string: NSString = self
		return string.stringByStandardizingPath
	}
	
	/// A new string made by shrinking *extraneous* path components from the receiver.
	var stringByShrinkingPath: String {
		var path = self.stringByStandardizingPath.pathComponents
		
		// Use short form "~" for home dir.
		if path[0...1] == ["/", "Users"] {
			path.removeRange(0...2)
			path = ["~"] + path
		}
		
		// Shortens large components (ie ≥ 20 chars) to only 9 chars.
		// For instance, "399A7349-B28BZCH-AE2F5E56B" would be "399...56B"
		for (i, item) in path.enumerate() {
			guard item.characters.count >= 20 else { continue }
			let startIndex = item.startIndex
			let endIndex = item.endIndex
			let prefix = startIndex..<startIndex.advancedBy(3)
			let suffix = endIndex.advancedBy(-3)..<endIndex
			let shorten = item[prefix] + "..." + item[suffix]
			assert(shorten.characters.count == 9)
			path[i] = shorten
		}
		
		return NSString.pathWithComponents(path)
	}
}

// MARK: - Regular Expressions

/// *Regex* creation syntax sugar (with no error handling).
///
/// For a quick guide, see:
/// * [NSRegularExpression Cheat Sheet and Quick Reference](http://goo.gl/5QzdhX)
func regex(pattern: String, options: NSRegularExpressionOptions = [ ])
-> NSRegularExpression {
	let regex = try! NSRegularExpression(pattern: pattern, options: options)
	return regex
}

/// Useful extensions for NSRegularExpression objects.
extension NSRegularExpression {
	
	/// Returns `true` if the specified string is fully matched by this regex.
	func matchesString(string: String) -> Bool {
		// Ranges are based on the UTF-16 *encoding*.
		let length = string.utf16.count
		precondition(length == (string as NSString).length)
		
		let wholeString = NSRange(location: 0, length: length)
		let matches = numberOfMatchesInString(string, options: [ ], range: wholeString)
		return matches == 1
	}
}

// MARK: - The Bare Bones Logging API ™

func log(message: String, file: String = #file, line: UInt = #line) {
	//let fileName = file.lastPathComponent.stringByDeletingPathExtension
	NSLog("\(message)")
	//NSLog("[\(fileName):\(line)] \(message)")
	//print("ℹ️ [\(fileName):\(line)] \(message)")
}

func logWarning(message: String, file: String = #file, line: UInt = #line) {
	NSLog("[WARNING] \(message)")
}

func logError(message: String, file: String = #file, line: UInt = #line) {
	//let fileName = file.lastPathComponent.stringByDeletingPathExtension
	NSLog("[ERROR] \(message)")
	//NSLog("[\(fileName):\(line)] ERROR: \(message)")
	//print("💀 [\(fileName):\(line)] \(message)")
}

// MARK: - Core Graphics

func rect(x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat)
	-> CGRect {
	return CGRectMake(x, y, width, height)
}

extension CGSize {

	/// Returns this size's *aspect ratio* (ie, `width / height`).
	var aspectRatio: CGFloat {
		assert(height > 0)
		return width / height
	}
}

extension CGRect {
	
	/// Quick and dirty `CGRect` rendering.
	/// This should *only* be used for debugging.
	func debugFill(color: UIColor = UIColor.greenColor(), alpha: CGFloat = 0.4) {
		color.setFill()
		let rectPath = UIBezierPath(rect: self)
		rectPath.fillWithBlendMode(.Normal, alpha: alpha)
	}
}

// MARK: - UIKit

/// Support for common *alerts*.
extension UIViewController {

	/// Shows alert popup with only 1 button.
	func showAlert(title title: String, message: String, ok: (() -> Void)? = nil) {
		let alert = UIAlertController(
			title: title, message: message, preferredStyle: .Alert)
		let okAction = UIAlertAction(title: "OK", style: .Default) {
			(action: UIAlertAction) -> Void in
			ok?()
		}
		alert.addAction(okAction)
		presentViewController(alert, animated: true, completion: nil)
	}

	/// Shows alert popup with *Yes* and *No* buttons.
	func showYesNoAlert(title title: String, message: String,
						yes: (() -> Void)?, no: (() -> Void)?) {
		let alertVC = UIAlertController(
			title: title, message: message, preferredStyle: .Alert)
		let noAction = UIAlertAction(title: "Non", style: .Default) {
			(action: UIAlertAction) -> Void in
			no?()
		}
		let yesAction = UIAlertAction(title: "Oui", style: .Default) {
			(action: UIAlertAction) -> Void in
			yes?()
		}
		alertVC.addAction(noAction)
		alertVC.addAction(yesAction)
		presentViewController(alertVC, animated: true, completion: nil)
	}
	
	/// Use this if you are *not* really sure what to show the user.
	func showAlertForError(error: Error, ok: (() -> Void)? = nil) {
		log("Showing ERROR:\n\(error)")
		switch error.code {
		case .internetConnectivityError:
			showInternetOfflineAlert(ok)
		default:
			showAlert(title: "Erreur", message: error.localizedDescription, ok: ok)
		}
	}
	
	/// Standard internet offline alert.
	func showInternetOfflineAlert(ok: (() -> Void)? = nil) {
		showAlert(
			title: "Erreur Internet", message:
			"Vous êtes déconnecté d'internet. " +
			"l'application geoCONFESS nécessite une connexion internet.") {
				ok?()
		}
	}
	
	func showLocalizationTrackingDeniedAlert(ok: (() -> Void)? = nil) {
		showAlert(
			title: "Géolocalisation", message:
			"Vous devez autoriser la géolocalisation " +
			"pour utiliser cette application.") {
				ok?()
		}
	}
}

private var progressHUDTimer: Timer?

/// Support for *progress HUD*.
extension UIViewController {
	
	// TODO: Review both methods below: `showProgressHUD` and `hideProgressHUD`.
	// There might be a better API design.
	
	/// Creates a new HUD, adds it to this view controller view and shows it.
	/// The counterpart to this method is `hideProgressHUD`.
	func showProgressHUD(animated animated: Bool = true, whiteColor: Bool = false) {
		hideProgressHUD(animated: false)
		/// Grace period is the time (in seconds) that the background operation
		/// may be run without showing the HUD. If the task finishes before the
		/// grace time runs out, the HUD will not be shown at all.
		///
		/// This *was* supposed to be done by the `graceTime` property, but it
		/// doesn't seem to be working at all. So we rolled our own implementation.
		let graceTime = 0.100
		progressHUDTimer = Timer.scheduledTimerWithTimeInterval(graceTime) {
			let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: animated)
			hud.taskInProgress = true
			hud.graceTime = 0
			hud.square = true
			hud.minSize = CGSize(width: 50, height: 50)
			if whiteColor {
				hud.color = UIColor.whiteColor()
				hud.activityIndicatorColor = UIColor.grayColor()
			}
		}
	}
	
	/// Finds all the HUD subviews and hides them.
	func hideProgressHUD(animated animated: Bool = true) {
		progressHUDTimer?.dispose()
		progressHUDTimer = nil
		for hud in MBProgressHUD.allHUDsForView(self.view) as! [MBProgressHUD] {
			hud.taskInProgress = false
			hud.hide(true)
		}
	}
}

extension UIButton {
	
	func setTargetForTap(target: AnyObject, _ action: Selector) {
		self.removeTarget(target, action: nil, forControlEvents: .AllTouchEvents)
		self.addTarget(target, action: action, forControlEvents: .TouchUpInside)
	}
}

extension UIColor {
	
	/// Creates a opaque color object using the specified RGB component values.
	convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
		self.init(red: red, green: green, blue: blue, alpha: 1.0)
	}
	
	/// Compares this color with the specified components in the RGB color space.
	func equalsRed(red: CGFloat, green: CGFloat, blue: CGFloat) -> Bool {
		var r = CGFloat(0)
		var g = CGFloat(0)
		var b = CGFloat(0)
		let converted = self.getRed(&r, green: &g, blue: &b, alpha: nil)
		precondition(converted, "color space not compatible with RGB")
		
		return r == red && g == green && b == blue
	}
}

extension String {
	
	/// Returns the bounding box size the string 
	/// occupies when drawn with the specified font.
	func sizeWithFont(font: UIFont) -> CGSize {
		let string: NSString = self
		let attribs = [NSFontAttributeName: font]
		let size = string.sizeWithAttributes(attribs)
		assert(size.width >= 0 && size.height >= 0)
		return size
	}
}

extension UIBarButtonItem {
	
	convenience init(barButtonSystemItem systemItem: UIBarButtonSystemItem,
					 width: CGFloat? = nil) {
		self.init(barButtonSystemItem: systemItem, target: nil, action: nil)
		if let width = width { self.width = width }
	}
}

extension UIGestureRecognizerState: CustomStringConvertible {
	
	public var description: String {
		switch self {
		case .Possible:  return "Possible"
		case .Began:     return "Began"
		case .Changed:   return "Changed"
		case .Ended:     return "Ended"
		case .Cancelled: return "Cancelled"
		case .Failed:    return "Failed"
		}
	}
}

extension UIApplicationState: CustomStringConvertible {
	
	public var description: String {
		switch self {
		case .Active:     return "Active"
		case .Inactive:   return "Inactive"
		case .Background: return "Background"
		}
	}
}

// MARK: - AutoLayout

/// This constraint requires the item's attribute
/// to be exactly **equal** to the specified value
func equalsConstraint(
	item item: AnyObject, attribute attrib1: NSLayoutAttribute, value: CGFloat)
	-> NSLayoutConstraint {
		
	return layoutConstraint(
		item: item, attribute: attrib1,
		relatedBy: .Equal,
		toItem: nil, attribute: .NotAnAttribute, constant: value)
}

/// This constraint requires the first attribute
/// to be exactly *equal* to the second attribute.
func equalsConstraint(
	item item: AnyObject, attribute attrib1: NSLayoutAttribute,
	     toItem: AnyObject?, attribute attrib2: NSLayoutAttribute,
	     multiplier: CGFloat = 1.0, constant: CGFloat = 0.0)
	-> NSLayoutConstraint {
	
	return layoutConstraint(
		item: item, attribute: attrib1,
		relatedBy: .Equal,
		toItem: toItem, attribute: attrib2,
		multiplier: multiplier, constant: constant)
}

/// Syntax sugar for `NSLayoutConstraint` init.
func layoutConstraint(
	item item: AnyObject, attribute attrib1: NSLayoutAttribute,
	     relatedBy: NSLayoutRelation,
	     toItem: AnyObject?, attribute attrib2: NSLayoutAttribute,
	     multiplier: CGFloat = 1.0, constant: CGFloat = 0.0)
	-> NSLayoutConstraint {
	
	return NSLayoutConstraint(
		item: item, attribute: attrib1,
		relatedBy: relatedBy,
		toItem: toItem, attribute: attrib2,
		multiplier: multiplier, constant: constant)
}

// MARK: - Preconditions Functions

/// Checks if we are running on the **main dispatch queue**
/// -- the one returned by `dispatch_get_main_queue()`.
func assertIsMainQueue(file: StaticString = #file, line: UInt = #line) {
	assert(
		NSThread.isMainThread(),
		"Code isn't running on the main dispatch queue",
		file: file, line: line
	)
}

/// Checks if we are running on the **main dispatch queue**
/// -- the one returned by `dispatch_get_main_queue()`.
func preconditionIsMainQueue(file: StaticString = #file, line: UInt = #line) {
	precondition(
		NSThread.isMainThread(),
		"Code isn't running on the main dispatch queue",
		file: file, line: line
	)
}

// MARK: - Timer Class

/// A simple timer class based on the `NSTimer` class.
/// Since this is `NSTimer` based, this also fires if the app in on the background.
final class Timer {
	
	// MARK: Private Stuff
	
	private let callback: Callback
	private var timer: NSTimer?
	
	private init(seconds: NSTimeInterval, repeats: Bool, _ callback: Callback) {
		precondition(seconds >= 0)
		self.callback = callback
		self.timer = NSTimer.scheduledTimerWithTimeInterval(
			NSTimeInterval(seconds),
			target: self, selector: #selector(self.timerDidFire),
			userInfo: nil, repeats: repeats)
	}
	
	deinit {
		dispose()
	}
	
	@objc private func timerDidFire() {
		assert(NSThread.isMainThread())
		assert(timer != nil)
		callback()
	}
	
	// MARK: Timer API
	
	typealias Callback = () -> Void
	
	/// Schedules timer and returns it. 
	/// If `repeats` is true a periodic timer is created.
	class func scheduledTimerWithTimeInterval(interval: NSTimeInterval,
	                                          repeats: Bool = false,
	                                          callback: Callback) -> Timer {
		return Timer(seconds: interval, repeats: repeats, callback)
	}
	
	/// Cancels timer.
	func dispose() {
		timer?.invalidate()
		timer = nil
	}
}

func runAfterDelay(delay: NSTimeInterval, block: dispatch_block_t) {
	let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
	dispatch_after(time, dispatch_get_main_queue(), block)
}


// MARK: - Core Location

enum Location {
	
	/// Unlike longitudinal distances, which vary based on the latitude,
	/// *one degree* of latitude is always approximately *111 kilometers* (69 miles).
	///
	/// The number of kilometers spanned by a longitude range varies based on the
	/// current latitude. For example, one degree of longitude spans a distance of
	/// approximately 111 kilometers (69 miles) at the equator but shrinks
	/// to 0 kilometers at the poles.
	static let kilometersPerLatitudeDegree = 111.0
}

extension CLLocation {

	convenience init(at location: CLLocationCoordinate2D) {
		self.init(latitude: location.latitude, longitude: location.longitude)
	}
}

extension CLLocationCoordinate2D {
	
	/// Inits location from `"latitude"` and `"longitude"` JSON encoded entries.
	init?(fromJSON json: [String: JSON]) {
		guard let latitude  = json["latitude"]?.double  else { return nil }
		guard let longitude = json["longitude"]?.double else { return nil }
		self.init(latitude: latitude, longitude: longitude)
	}
}

extension CLLocationCoordinate2D: CustomStringConvertible {
	
	public var description: String {
		return String(format: "latitude: %.5f, longitude: %.5f", latitude, longitude)
	}
	
	var shortDescription: String {
		return String(format: "%.2f, %.2f", latitude, longitude)
	}
}

extension CLLocationCoordinate2D: Equatable, Hashable {
	
	public var hashValue: Int {
		return Int(latitude*100) + Int(longitude*100)*10_000
	}
}

public func ==(left: CLLocationCoordinate2D, right: CLLocationCoordinate2D) -> Bool {
	return left.latitude  == right.latitude &&
		   left.longitude == right.longitude
}

extension CLAuthorizationStatus: CustomStringConvertible {
	
	public var description: String {
		switch self {
		case NotDetermined:
			return "NotDetermined"
		case Restricted:
			return "Restricted"
		case Denied:
			return "Denied"
		case AuthorizedAlways:
			return "AuthorizedAlways"
		case AuthorizedWhenInUse:
			return "AuthorizedWhenInUse"
		}
	}
}

// MARK: - NSBundle

extension NSBundle {

	/// Returns the iOS Simulator path, if available.
	var simulatorPath: String? {
		// Looking for this: 
		// ~/Library/Developer/CoreSimulator/Devices/SIMULATOR_ID/...
		let bundlePath = self.bundlePath.pathComponents
		for (i, dir) in bundlePath.enumerate() {
			if dir == "CoreSimulator" {
				return bundlePath[0...(i + 2)].joinWithSeparator("/")
			}
		}
		return nil
	}

	/// Returns the relative *bundle path* (from iOS Simulator path), if available.
	var bundlePathFromSimulator: String? {
		guard let simulatorPath = self.simulatorPath else { return nil }
		var bundlePath = self.bundlePath
		bundlePath.removeRange(simulatorPath.startIndex..<simulatorPath.endIndex)
		return bundlePath
	}

	/// Returns the relative *temporary dir* (from iOS Simulator path), if available.
	var temporaryDirectoryFromSimulator: String? {
		guard let simulatorPath = self.simulatorPath else { return nil }
		var tmpPath = NSTemporaryDirectory()
		tmpPath.removeRange(simulatorPath.startIndex..<simulatorPath.endIndex)
		return tmpPath
	}
}

// MARK: - MapKit

extension MKMapCamera {
	
	/// Creates a `MKMapCamera` at the specified location.
	convenience init(at centerCoordinate: CLLocationCoordinate2D) {
		self.init()
		self.centerCoordinate = centerCoordinate
	}
}

// MARK: - Google Maps

extension GMSCameraPosition {
	
	/// Creates a `GMSCameraPosition` instance with default zoom level.
	convenience init(at location: CLLocationCoordinate2D, zoom: Float = 12.0) {
		self.init(target: location, zoom: zoom, bearing: 0, viewingAngle: 0)
	}
}

// MARK: - Pseudo Random Numbers

/// Returns randomized `Double` value in the `0.0` to `1.0` range.
///
/// Based on `random()` function from stdlib. 
/// Seed can be controlled via via `srandom()`.
func randomDouble() -> Double {
	let rand = Double(random()) / Double(Int32.max)
	assert(rand >= 0.0 && rand <= 1.0)
	return rand
}

/// Returns randomized `Double` value in the specified range.
///
/// Based on `random()` function from stdlib.
/// Seed can be controlled via via `srandom()`.
func randomDoubleInRange(range: ClosedInterval<Double>) -> Double {
	let rand = range.start + randomDouble() * (range.end - range.start)
	assert(range.contains(rand))
	return rand
}

/// Returns randomized `Double` value in the specified range.
///
/// Based on `random()` function from stdlib.
/// Seed can be controlled via via `srandom()`.
func randomIntInRange(range: Range<Int>) -> Int {
	let modulo = range.endIndex - range.startIndex
	precondition(modulo > 0)
	let rand = range.startIndex + (random() % modulo)
	assert(rand >= range.startIndex && rand < range.endIndex)
	return rand
}

/// Returns randomized `Bool` value.
///
/// Based on `random()` function from stdlib.
/// Seed can be controlled via via `srandom()`.
func randomBool() -> Bool {
	return randomDouble() > 0.5
}

extension CollectionType where Index.Distance == Int {
	
	/// Returns a random element from this collection.
	func randomElement() -> Generator.Element? {
		let count = Int(self.count)
		guard count > 0 else { return nil }
		let randomIndex = randomIntInRange(0..<count)
		return self[startIndex.advancedBy(randomIndex)]
	}
}

// MARK: - Observers

/// A facility for observers of single events (ie, one time events).
/// The registered `completion` function will be called *once* at most.
final class SingleEventObservers<Callback> {
	// TODO: Still looking for the correct design here.
}

// MARK: - Weak References

/// Wrapper for *weak references*.
/// Useful for storing weak references in collections, for instance.
///
/// ♨️ **Android Hint**. This struct is very similar
/// to the **[java.lang.ref.WeakReference<T>](https://goo.gl/WQd8Je)** class.
struct Weak<T: AnyObject>: Equatable, Hashable, CustomStringConvertible {
	
	private weak var objectRef: T?
	private let stableAndFastHashValue: Int
	
	init(_ object: T) {
		self.objectRef = object
		self.stableAndFastHashValue = unsafeAddressOf(object).hashValue
	}
	
	var object : T? {
		return objectRef
	}
	
	var hashValue: Int {
		// It is not a good design to have a non-constant hashcode.
  		// For instance, this enables this struct to be safely used as dictionary keys.
		return stableAndFastHashValue
	}
	
	var description: String {
		let objectDesc: String
		if let object = objectRef {
			objectDesc = String(object)
		} else {
			objectDesc = "nil"
		}
		return "Weak(\(objectDesc))"
	}
}

/// `Equatable` protocol.
func ==<T: AnyObject>(lhs: Weak<T>, rhs: Weak<T>) -> Bool {
	return lhs.object === rhs.object
}

// MARK: - Swift 3 Hacks

//typealias IndexPath = NSIndexSet
