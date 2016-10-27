//
//  Objects.swift
//  GeoConfess
//
//  Created  by Andreas Muller on 4/6/16.
//  Reviewed by Dan Dobrev on 5/9/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// MARK: - REST Object

/// Type for all unique, REST-ish resources ID.
typealias ResourceID = UInt64

/// A top-level protocol for REST-ish objects/resources.
protocol RESTObject: CustomStringConvertible {
	
	/// Uniquely identifies this resource.
	var id: ResourceID { get }
}

/// Default implementations.
extension RESTObject {
	
	var description: String {
		return "\(self.dynamicType)(id: \(self.id))"
	}
}

// MARK: - JSON Coding

/// JSON encoding.
extension JSON {
	
	init(_ id: ResourceID) {
		self.init(NSNumber(unsignedLongLong: id))
	}
	
	var resourceID: ResourceID? {
		return self.uInt64
	}
}

/// Support for **JSON** compatible decoding.
protocol JSONDecoding {
	
	/// Parses a JSON-encoded representation of this object.
	init?(fromJSON: JSON)
}

/// Support for **JSON** compatible encoding.
protocol JSONCoding {
	
	/// Returns a JSON-encoded representation of this object.
	func toJSON() -> JSON
}

// MARK: - DisplayDescription Protocol

protocol DisplayDescription {
	
	var displayDescription: String { get }
}

// MARK: - UserInfo Struct

/// Partial information about a given **penitent** or **priest**.
struct UserInfo: RESTObject, Equatable, JSONCoding {
    
    let id: ResourceID
    let name: String
    let surname: String
	
	/// Priest has location if he is active right *now*.
	let location: CLLocationCoordinate2D?
	
    init(id: ResourceID,
         name: String,
         surname: String,
         location: CLLocationCoordinate2D? = nil) {
        self.id       = id
        self.name     = name
        self.surname  = surname
		self.location = location
    }
	
	init(fromJSON json: [String: JSON]) {
		precondition(json.count <= 5)
		
		let id      = json["id"]!.resourceID!
		let name    = json["name"]!.string!
		let surname = json["surname"]!.string!
		
		let location: CLLocationCoordinate2D?
		if let lat = json["latitude"]?.double, let lon = json["longitude"]?.double {
			location = CLLocationCoordinate2D(
				latitude:  CLLocationDegrees(lat),
				longitude: CLLocationDegrees(lon))
		} else {
			location = nil
		}
		
		self.init(id: id, name: name, surname: surname, location: location)
	}
	
	func toJSON() -> JSON {
		var json: [String: JSON] = [
			"id":      JSON(id),
			"name":    JSON(name),
			"surname": JSON(surname)
		]
		if let location = self.location {
			json["latitude"]  = JSON(location.latitude)
			json["longitude"] = JSON(location.longitude)
		}
		return JSON(json)
	}

	init(fromUser user: User) {
		let id       = user.id
		let name     = user.name
		let surname  = user.surname
		let location = user.location?.coordinate
		
		self.init(id: id, name: name, surname: surname, location: location)
	}
	
	/// Parses complete/partial user info from the specified dictionary.
	/// For example:
	///
	/// 		{
	/// 			"id": 10,
	/// 			"priest_id": 24,
	/// 			...
	/// 			"penitent": {
	/// 				"id": 25,
	/// 				"name": "Test user",
	/// 				"surname": "Surname",
	/// 				"latitude": "12.234",
	/// 				"longitude": "23.345"
	/// 			}
	/// 		}
	///
	/// If extended information is missing, we assume it most
	/// be about the current user (and fulfill it accordingly).
	init?(embeddedInJSON json: [String: JSON], forRole role: User.Role) {
		let userKey: String
		switch role {
		case .Penitent, .Admin:
			userKey = "penitent"
		case .Priest:
			userKey = "priest"
		}
		
		if let singleId = json["\(userKey)_id"]?.resourceID {
			precondition(json[userKey] == nil)
			self.init(copyFromCurrentUserWithID: singleId)
		} else if let userJSON = json[userKey]?.dictionary {
			if userJSON.count == 1 {
				self.init(copyFromCurrentUserWithID: userJSON["id"]!.resourceID!)
			} else {
				self.init(fromJSON: userJSON)
			}
		} else {
			return nil
		}
	}
	
	private init(copyFromCurrentUserWithID id: ResourceID) {
		let user = User.current!
		precondition(user.id == id, "Expecting current user")
		self.init(id: id, name: user.name, surname: user.surname, location: nil)
	}
}

func ==(x: UserInfo, y: UserInfo) -> Bool {
	return x.id == y.id && x.name == y.name && x.surname == y.surname
}
