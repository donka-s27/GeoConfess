//
//  Spot.swift
//  GeoConfess
//
//  Created by Donka on 5/9/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import AddressBook
import Contacts

// MARK: - Spot Class

/// A spot is a **place** the **priest** has set to meet.
/// See the `Priest` class for more operations for manipulating spots.
///
/// Instance of this class are *quasi-immutable* by design.
final class Spot: Equatable, Hashable {
	
	/// A spot can be **static** or **dynamic**.
	enum ActivityType {
		
		/// A *static* spot can be a church or any fixed
		/// place the priest is regularly avaiable for meeting.
		///
		/// The recurrence array specifies when the priest might be available.
		case Static(Address, [Recurrence])
		
		/// A *dynamic* spot is based on the priest current location.
		///
		/// If a dynamic spot already *exists* it will be reused if priest 
		/// tries to create another one. In the backend, there is also a job
		/// which automatically removes dynamic spots older than 15 minutes.
		case Dynamic
		
		private var shortDescription: String {
			switch self {
			case .Static:  return "static"
			case .Dynamic: return "dynamic"
			}
		}
	}
	
	/// Uniquely identifies this spot.
	/// If this is a new spot, the id will be `nil`.
	let id: ResourceID!
	
	/// This spot name.
	let name: String
	
	/// Spot's activity type.
	let activityType: ActivityType
	
	/// Static spot's recurrence.
	/// This is *only* available if this is a static spot.
	var address: Address? {
		switch activityType {
		case .Static(let address, _):
			return address
		case .Dynamic:
			return nil
		}
	}

	/// Static spot's recurrence.
	/// This is *only* available if this is a static spot.
	var recurrence: Recurrence? {
		switch activityType {
		case .Static(_, let recurrences):
			return recurrences.first!
		case .Dynamic:
			return nil
		}
	}
	
	/// The priest available at this spot.
	let priest: UserInfo
	
	var hashValue: Int {
		if let id = id {
			return Int(id)
		} else {
			return 0
		}
	}
	
	weak var delegate: SpotDelegate?
	
	/// Creates a new spot.
	init(id: ResourceID!,
	     name: String,
	     activityType: ActivityType,
	     location: CLLocation,
	     priest: UserInfo) {
		
		self.id = id
		self.name = name
		self.activityType = activityType
		self.location = location
		self.priest = priest
	}
	
	/// Parses JSON-encoded spot. See the
	/// [API documentation](https://geoconfess.herokuapp.com/apidoc/V1/spots.html)
	/// for some examples.
	convenience init?(fromJSON jsonValue: JSON, forPriest: UserInfo? = nil) {
		// We only really check core stuff -- all remaining errors will crash the app.
		guard let json = jsonValue.dictionary   else { return nil }
		guard let id   = json["id"]?.resourceID else { return nil }
		guard let name = json["name"]?.string   else { return nil }
		
		let location = CLLocation(at: CLLocationCoordinate2D(fromJSON: json)!)
		let activityType: ActivityType
		switch json["activity_type"]!.string! {
		case "static":
			let address = Address(fromJSON: JSON(json))!
			let recurrencesJSON = json["recurrences"]?.array ?? [ ]
			let recurrences = recurrencesJSON.map {
				Recurrence(fromJSON: $0)!
			}
			activityType = .Static(address, recurrences)
		case "dynamic":
			activityType = .Dynamic
		default:
			preconditionFailure("Unexpected activity_type")
		}
		
		let priest: UserInfo
		if let priestJSON = json["priest"]?.dictionary {
			priest = UserInfo(fromJSON: priestJSON)
			if forPriest != nil { precondition(forPriest == priest) }
		} else {
			precondition(forPriest != nil)
			priest = forPriest!
		}
		
		self.init(id: id, name: name, activityType: activityType,
		          location: location, priest: priest)
	}
	
	/// Returns a JSON-encoded representation of this spot.
	func toJSON(putPriest: Bool = false) -> [String: JSON] {
		var jsonSpot = [String: JSON]()
		
		if id != nil { jsonSpot["id"] = JSON(id!) }
		jsonSpot["name"] = JSON(name)
		jsonSpot["latitude"]  = JSON(location.coordinate.latitude)
		jsonSpot["longitude"] = JSON(location.coordinate.longitude)
		
		switch activityType {
		case .Static(let address, let recurrences):
			jsonSpot["activity_type"] = "static"
			for (key, value) in address.toJSON().dictionary! {
				jsonSpot[key] = value
			}
			if recurrences.count > 0 {
				jsonSpot["recurrences"] = JSON(recurrences.map { $0.toJSON() })
			}
		case .Dynamic:
			jsonSpot["activity_type"] = "dynamic"
		}
		precondition(putPriest == false)
		
		return jsonSpot
	}
	
	// MARK: Backend Operations
	
	/// Creates this spot on the backend.
	func createSpot(completion: Result<Spot, NSError> -> Void) {
		precondition(id == nil)
		guard let priest = User.currentPriest else { preconditionFailure() }

		// New spot data.
		let requiredFields = ["name", "activity_type", "latitude", "longitude"]
		let optionalFields = ["street", "postcode", "city", "state", "country"]
		var newSpot = [String: String]()
		let jsonSpot = toJSON()
		for key in requiredFields {
			newSpot[key] = String(jsonSpot[key]!)
		}
		for key in optionalFields {
			if let value = jsonSpot[key] {
				newSpot[key] = String(value)
			}
		}
		
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/spots/create.html
		let createSpotURL = "\(App.serverAPI)/spots"
		let parameters: [String: AnyObject] = [
			"access_token": priest.oauth.accessToken,
			"spot": newSpot
		]
		Alamofire.request(.POST, createSpotURL, parameters: parameters).responseJSON {
			response in
			preconditionIsMainQueue()
			switch response.result {
			case .Success(let value):
				let priestInfo = UserInfo(fromUser: priest)
				let newSpot = Spot(fromJSON: JSON(value), forPriest: priestInfo)!
				completion(.Success(newSpot))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	/// Delete this spot on the backend.
	func deleteSpot(userTokens oauth: OAuthTokens,
					completion: Result<Void, NSError> -> Void) {
		guard let id = self.id else { preconditionFailure() }
		
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/spots.html#description-destroy
		let deleteSpotURL = "\(App.serverAPI)/spots/\(id)"
		let params: [String: AnyObject] = [
			"access_token": oauth.accessToken
		]
		Alamofire.request(.DELETE, deleteSpotURL, parameters: params).responseString {
			response in
			preconditionIsMainQueue()
			switch response.result {
			case .Success(let value):
				assert(value == "")
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	/// Finds all spots near the specified location.
	static func getSpotsNearLocation(location: CLLocationCoordinate2D,
	                                 _ distance: Double, onlyActive: Bool,
	                                 _ queue: dispatch_queue_t! = nil,
	                                 completion: Result<Set<Spot>, Error> -> Void) {
		guard let user = User.current else { preconditionFailure() }
		
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/spots.html#description-index
		let listSpotURL = "\(App.serverAPI)/spots"
		var params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
			"lat": location.latitude,
			"lng": location.longitude,
			"distance": distance
		]
		if onlyActive {
			params["now"] = "true"
		}
		let httpRequest = Alamofire.request(.GET, listSpotURL, parameters: params)
		httpRequest.validate().responseJSON(queue: queue) {
			response in
			switch response.result {
			case .Success(let value):
				var nearbySpots = Set<Spot>()
				for spotJSON in JSON(value).array! {
					let spot = Spot(fromJSON: spotJSON)!
					assert(nearbySpots.contains(spot) == false)
					nearbySpots.insert(spot)
				}
				completion(.Success(nearbySpots))
			case .Failure(let error):
				completion(.Failure(Error(causedBy: error)))
			}
		}
	}
	
	// MARK: Geolocating the Spot

	/// Spot location on the map.
	private(set) var location: CLLocation {
		didSet {
			if location != oldValue {
				delegate?.spotLocationDidUpdate(self, newLocation: location)
			}
		}
	}
	
	/// Updates this spot **location** on the backend.
	func setLocation(location: CLLocation,
	                 completion: Result<Void, NSError> -> Void) {
		precondition(id != nil)
		guard let priest = User.currentPriest else { preconditionFailure() }
		
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/spots/update.html
		let updateSpotURL = "\(App.serverAPI)/spots/\(id)"
		let spot: [String: AnyObject] = [
			"latitude":  location.coordinate.latitude,
			"longitude": location.coordinate.longitude
		]
		let params: [String: AnyObject] = [
			"access_token": priest.oauth.accessToken,
			"spot": spot
		]
		
		let spotDesc = "\(activityType.shortDescription) spot"
		log("Setting location of \(spotDesc) \(id)\nParameters:\n\(JSON(params))")
		let oldLocation = self.location
		self.location = location
		Alamofire.request(.PATCH, updateSpotURL, parameters: params).responseJSON {
			response in
			preconditionIsMainQueue()
			switch response.result {
			case .Success(let value):
				assert(JSON(value).dictionary!["result"]!.string! == "success")
				completion(.Success())
			case .Failure(let error):
				self.location = oldLocation
				completion(.Failure(error))
			}
		}
	}
}

func ==(left: Spot, right: Spot) -> Bool {
	// We shouldn't compare `CLLocation` objects 
	// directly because timestamp will never match.
	// We also don't care about `horizontalAccuracy` or `verticalAccuracy`.
	return
		left.id                  == right.id   &&
		left.name                == right.name &&
		left.location.coordinate == right.location.coordinate
}

/// A simple spot delegate.
protocol SpotDelegate: class {
	
	func spotLocationDidUpdate(spot: Spot, newLocation: CLLocation)
}

// MARK: - Spot Sequence

extension SequenceType where Generator.Element: Spot {

	func priestDynamicSpot(priestID: ResourceID) -> Spot? {
		for spot in self {
			switch spot.activityType {
			case .Dynamic:
				if spot.priest.id == priestID {
					return spot
				}
			case .Static:
				break
			}
		}
		return nil
	}
}

// MARK: - Spot Recurrence Class

/// One or more days a given priest is available for a meeting.
final class Recurrence: RESTObject, JSONCoding, JSONDecoding, DisplayDescription {
	
	let id: ResourceID
	let spotID: ResourceID
	
	let startAt: Time
	let stopAt:  Time
	
	let schedule: Recurrence.Schedule
	
	/// Recurrence scheduling style.
	enum Schedule {
		case SingleDate(Date)
		case Weekly(Set<Weekday>)
	}
	
	init(id: ResourceID, spotID: ResourceID,
	     startAt: Time, stopAt: Time, at schedule: Recurrence.Schedule) {
		self.id       = id
		self.spotID   = spotID
		self.startAt  = startAt
		self.stopAt   = stopAt
		self.schedule = schedule
	}
	
	/// Parses JSON-encoded recurrence. The supported formats are:
	///
	///     {
	///       "id": 2,
	///       "spot_id": 10,
	///       "start_at": "10:00",
	///       "stop_at": "20:00",
	///       "week_days": ["Tuesday", "Friday"]
	///     }
	///
	/// Or:
	///
	///     {
	///       "id": 4,
	///       "spot_id": 10,
	///       "start_at": "10:00",
	///       "stop_at": "20:00",
	///       "date": "2016-04-11"
	///     }
	///
	/// See the
	/// [API documentation](https://geoconfess.herokuapp.com/apidoc/V1/spots.html)
	/// for more information.
	convenience init?(fromJSON jsonValue: JSON) {
		guard let json = jsonValue.dictionary else { return nil }
		guard json.count == 5 else { return nil }
		
		let id      = json["id"]!.resourceID!
		let spotID  = json["spot_id"]!.resourceID!
		let startAt = Time(parse: json["start_at"]!.string!)!
		let stopAt  = Time(parse: json["stop_at"]!.string!)!
		
		let schedule: Schedule
		if let date = json["date"]?.string {
			schedule = Schedule.SingleDate(Date(parse: date)!)
		} else if let weekdDaysJSON = json["week_days"]?.array {
			let weekDays = weekdDaysJSON.map { Weekday(rawValue: $0.string!)! }
			schedule = Schedule.Weekly(Set(weekDays))
		} else {
			preconditionFailure("illegal recurrence JSON format")
		}
		
		self.init(id: id, spotID: spotID,
		          startAt: startAt, stopAt: stopAt, at: schedule)
	}
	
	/// Returns JSON-encoded representation of this recurrence.
	func toJSON() -> JSON {
		var json = [String: JSON]()
		
		json["id"] = JSON(id)
		json["spot_id"] = JSON(spotID)
		json["start_at"] = startAt.toJSON()
		json["stop_at"] = stopAt.toJSON()
		
		switch schedule {
		case .SingleDate(let date):
			json["date"] = date.toJSON()
		case .Weekly(let weekdays):
			json["week_days"] = JSON(weekdays.map { $0.toJSON() })
		}
		
		return JSON(json)
	}
	
	var displayDescription: String {
		let startAt = self.startAt.displayDescription
		let stopAt  = self.stopAt.displayDescription
		switch schedule {
		case .SingleDate(let date):
			return "\(startAt)-\(stopAt), \(date.displayDescription)"
		case .Weekly(let weekdays):
			let days = weekdays.map { $0.displayDescription }.joinWithSeparator(", ")
			return "\(startAt)-\(stopAt), \(days)"
		}
	}
}

// MARK: - Time Struct

/// A time during the day, with *minutes* precison.
/// Useful for human communication.
struct Time: Comparable, CustomStringConvertible,
			 JSONCoding, JSONDecoding, DisplayDescription {
	
	var hour: UInt {
		didSet {
			precondition(hour <= 23)
		}
	}
	
	var minute: UInt {
		didSet {
			precondition(minute <= 59)
		}
	}
	
	init() {
		self.hour   = 0
		self.minute = 0
	}
	
	init(hour: UInt, minute: UInt) {
		precondition(hour <= 23 && minute <= 59)
		self.hour   = hour
		self.minute = minute
	}
	
	/// Parses string-encoded time in a `"HH:MM"` format.
	init?(parse stringTime: String) {
		let hourAndMinute = stringTime.componentsSeparatedByString(":")
		guard hourAndMinute.count == 2 else { return nil }
		
		guard let hour   = UInt(hourAndMinute[0]) else { return nil }
		guard let minute = UInt(hourAndMinute[1]) else { return nil }
		self.init(hour: hour, minute: minute)
	}
	
	init?(fromJSON json: JSON) {
		guard let stringTime = json.string else { return nil }
		self.init(parse: stringTime)
	}
	
	func toJSON() -> JSON {
		return JSON(description)
	}
	
	/// A textual representation of `self`.
	var description: String {
		return "\(hour):\(minute)"
	}
	
	var displayDescription: String {
		if minute == 0 {
			return "\(hour)h"
		} else {
			let minuteStr = String(format: "%02d", minute)
			return "\(hour):\(minuteStr)h"
		}
	}
}

func ==(x: Time, y: Time) -> Bool {
	return x.hour == y.hour && x.minute == y.minute
}

func <(x: Time, y: Time) -> Bool {
	if x.hour < y.hour { return true }
	return x.hour == y.hour && x.minute < y.minute
}

// MARK: - Date Struct

/// A specific day.
/// Useful for human communication.
struct Date: Equatable, CustomStringConvertible,
		     JSONCoding, JSONDecoding, DisplayDescription {
	
	var day: UInt {
		didSet {
			precondition(day >= 1 && day <= 31)
		}
	}
	
	var month: UInt {
		didSet {
			precondition(month >= 1 && month <= 12)
		}
	}
	
	var year: UInt
	
	init() {
		self.day   = 1
		self.month = 1
		self.year  = 2016
	}
	
	init(day: UInt, month: UInt, year: UInt) {
		precondition(day <= 31 && month <= 12)
		self.day   = day
		self.month = month
		self.year  = year
	}
	
	/// Parses string-encoded date in a `"YYYY-MM-DD"` format.
	init?(parse stringDate: String) {
		let components = stringDate.componentsSeparatedByString("-")
		guard components.count == 3 else { return nil }
		
		guard let year  = UInt(components[0]) else { return nil }
		guard let month = UInt(components[1]) else { return nil }
		guard let day   = UInt(components[2]) else { return nil }
		self.init(day: day, month: month, year: year)
	}
	
	init?(fromJSON json: JSON) {
		guard let stringDate = json.string else { return nil }
		self.init(parse: stringDate)
	}
	
	func toJSON() -> JSON {
		return JSON(description)
	}

	/// A textual representation of `self`.
	var description: String {
		return String(format: "%.4d-%.2d-%.2d", year, month, day)
	}
	
	var displayDescription: String {
		return String(format: "%.2d/%.2d/%.4d", day, month, year)
	}
	
	init(fromDate date: NSDate) {
		let calendar = NSCalendar.currentCalendar()
		let components = calendar.components([.Day, .Month, .Year], fromDate: date)
		self.day   = UInt(components.day)
		self.month = UInt(components.month)
		self.year  = UInt(components.year)
	}
	
	func toNSDate() -> NSDate {
		let components = NSDateComponents()
		components.day   = Int(day)
		components.month = Int(month)
		components.year  = Int(year)
		
		let calendar = NSCalendar.currentCalendar()
		return calendar.dateFromComponents(components)!
	}
}

func ==(x: Date, y: Date) -> Bool {
	return x.day == y.day && x.month == y.month && x.year == y.year
}

// MARK: - Weekday Enum

/// A given weekday.
enum Weekday: String, Equatable, Hashable, CustomStringConvertible,
			  JSONCoding, JSONDecoding, DisplayDescription {
	
	case Monday    = "Monday"
	case Tuesday   = "Tuesday"
	case Wednesday = "Wednesday"
	case Thursday  = "Thursday"
	case Friday    = "Friday"
	case Saturday  = "Saturday"
	case Sunday    = "Sunday"
	
	static let week: [Weekday] = [
		.Monday, .Tuesday, .Wednesday, .Thursday, .Friday,
		.Saturday, .Sunday
	]
	
	/// Returns this weekday localized in the current language.
	var localizedName: String {
		switch self {
		case .Monday:    return "Lundi"
		case .Tuesday:   return "Mardi"
		case .Wednesday: return "Mercredi"
		case .Thursday:  return "Jeudi"
		case .Friday:    return "Vendredi"
		case .Saturday:  return "Samedi"
		case .Sunday:    return "Dimanche"
		}
	}
	
	init?(fromJSON json: JSON) {
		guard let rawValue = json.string else { return nil }
		self.init(rawValue: rawValue)
	}
	
	func toJSON() -> JSON {
		return JSON(rawValue)
	}
	
	/// A textual representation of `self`.
	var description: String {
		return self.rawValue
	}
	
	var displayDescription: String {
		switch self {
		case .Monday:    return "Lu"
		case .Tuesday:   return "Ma"
		case .Wednesday: return "Me"
		case .Thursday:  return "Je"
		case .Friday:    return "Ve"
		case .Saturday:  return "Sa"
		case .Sunday:    return "Di"
		}
	}
	
	var hashValue: Int {
		return rawValue.hashValue
	}
}

func ==(x: Weekday, y: Weekday) -> Bool {
	return x.description == y.description
}

// MARK: - Address Struct

/// Address information.
/// Not all fields might be available.
struct Address: JSONCoding, JSONDecoding, DisplayDescription {
	
	var street: String!
	var postCode: String!
	var city: String!
	var state: String!
	
	// ISO country code.
	var country: String!
	
	/// Creates empty address.
	init() {
		self.street   = nil
		self.postCode = nil
		self.city     = nil
		self.state    = nil
		self.country  = nil
	}

	init(street: String, postCode: String, city: String,
	     state: String, country: String) {
		
		self.street = street
		self.postCode = postCode
		self.city = city
		self.state = state
		self.country = country
	}
	
	/// Parses JSON-encoded address.
	init?(fromJSON json: JSON) {
		guard let dict = json.dictionary else { return nil }
		
		self.street   = dict["street"]?.string
		self.postCode = dict["postcode"]?.string
		self.city     = dict["city"]?.string
		self.state    = dict["state"]?.string
		self.country  = dict["country"]?.string
	}
	
	/// Returns JSON-encoded representation of this address.
	func toJSON() -> JSON {
		var dict = [String: JSON]()
		
		dict["street"]   = JSON(street   ?? "")
		dict["postcode"] = JSON(postCode ?? "")
		dict["city"]     = JSON(city     ?? "")
		dict["state"]    = JSON(state    ?? "")
		dict["country"]  = JSON(country  ?? "")
		
		return JSON(dict)
	}
	
	var displayDescription: String {
		var address = [String]()
		if let street   = self.street   { address.append(street)	 }
		if let city     = self.city     { address.append(city)   }
		return address.joinWithSeparator(", ")
	}
	
	// MARK: Address Book Support
	
	init(addressBook: [String: AnyObject]) {
		func get(key key: String) -> String? {
			return addressBook[key] as? String
		}

		if #available(iOS 9, *) {
			self.street   = get(key: CNPostalAddressStreetKey)
			self.postCode = get(key: CNPostalAddressPostalCodeKey)
			self.city     = get(key: CNPostalAddressCityKey)
			self.state    = get(key: CNPostalAddressStateKey)
			self.country  = get(key: CNPostalAddressISOCountryCodeKey)
		} else {
			self.street   = get(key: String(kABPersonAddressStreetKey))
			self.postCode = get(key: String(kABPersonAddressZIPKey))
			self.city     = get(key: String(kABPersonAddressCityKey))
			self.state    = get(key: String(kABPersonAddressStateKey))
			self.country  = get(key: String(kABPersonAddressCountryCodeKey))
		}
	}
	
	/// A dictionary containing keys and values from an *Address Book* record.
	func addressBookDictionary() -> [String: AnyObject] {
		var address = [String: AnyObject]()
		func set(key key: String, value: String?) {
			guard let value = value else { return }
			address[key] = value
		}
		
		if #available(iOS 9, *) {
			set(key: CNPostalAddressStreetKey,         value: street)
			set(key: CNPostalAddressPostalCodeKey,     value: postCode)
			set(key: CNPostalAddressCityKey,           value: city)
			set(key: CNPostalAddressStateKey,          value: state)
			set(key: CNPostalAddressISOCountryCodeKey, value: country)
		} else {
			set(key: String(kABPersonAddressStreetKey),      value: street)
			set(key: String(kABPersonAddressZIPKey),         value: postCode)
			set(key: String(kABPersonAddressCityKey),        value: city)
			set(key: String(kABPersonAddressStateKey),       value: state)
			set(key: String(kABPersonAddressCountryCodeKey), value: country)
		}

		return address
	}
}
