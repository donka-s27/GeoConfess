//
//  SpotEditor.swift
//  GeoConfess
//
//  Created by Donka on June 8, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

/// Tracks editing to a static spot's *recurrence*.
final class SpotEditor {

	/// The spot being edited. 
	/// This spot recurrence is stored by this editor object.
	let spot: Spot

	/// This spot address.
	let address: Address

	/// The specified recurrence being edited.
	private(set) var recurrence: Recurrence?
	
	/// Only available if recurrence's schedule is `SingleDate`.
	var recurrenceSingleDate: Date? {
		if recurrence == nil { return nil }
		switch recurrence!.schedule {
		case .SingleDate(let date):
			return date
		case .Weekly:
			return nil
		}
	}

	/// Only available if recurrence's schedule is `Weekly`.
	var recurrenceWeekdays: Set<Weekday>? {
		if recurrence == nil { return nil }
		switch recurrence!.schedule {
		case .SingleDate:
			return nil
		case .Weekly(let weekdays):
			return weekdays
		}
	}

	// MARK: - Creating Spot Editor
	
	/// Creates editor for the specified spot's *single* recurrence (or *none*).
	private init(editSpot spot: Spot, recurrence: Recurrence?) {
		switch spot.activityType {
		case .Static(let address, _):
			self.address = address
			self.recurrence = recurrence
		case .Dynamic:
			preconditionFailure("SpotEditor only works for static spots")
		}
		self.spot = Spot(
			id: spot.id,
			name: spot.name,
			activityType: Spot.ActivityType.Static(address, [ /*empty */ ]),
			location: spot.location,
			priest: spot.priest
		)
	}
	
	/// Creates a new static spot and returns an spot editor for each recurrence it.
	static func createSpot(name: String, address: Address, location: CLLocation,
	                       completion: Result<SpotEditor, NSError> -> Void) {
		guard let priest = User.currentPriest else {
			preconditionFailure("Spot editing only available to priests")
		}
		let newSpot = Spot(
			id: nil,
			name: name,
			activityType: Spot.ActivityType.Static(address, [ ]),
			location: location,
			priest: UserInfo(fromUser: priest)
		)
		newSpot.createSpot {
			result in
			switch result {
			case .Success(let spot):
				let spotEditor = SpotEditor(editSpot: spot, recurrence: nil)
				completion(.Success(spotEditor))
			case .Failure(let error):
				assertionFailure("createSpot failed: \(error)")
				completion(.Failure(error))
			}
		}
	}
	
	static func editorsForSpots(spots: [Spot]) -> [SpotEditor] {
		var editors = [SpotEditor]()
		for spot in spots {
			switch spot.activityType {
			case .Static(_	, let recurrences):
				for recurrence in recurrences {
					editors.append(SpotEditor(editSpot: spot, recurrence: recurrence))
				}
			case .Dynamic:
				preconditionFailure("SpotEditor only works for static spots")
			}
		}
		return editors
	}

	static func spotsEditedBy(editors: [SpotEditor]) -> [Spot] {
		var spots = [ResourceID: Spot]()
		var recurrencesBySpot = [ResourceID: [Recurrence]]()
		for editor in editors {
			guard let recurrence = editor.recurrence else { continue }
			var recurrences = recurrencesBySpot[editor.spot.id] ?? [ ]
			recurrences.append(recurrence)
			recurrencesBySpot[editor.spot.id] = recurrences
			spots[editor.spot.id] = editor.spot
		}
		for (spotID, newRecurrences) in recurrencesBySpot {
			let spot = spots[spotID]!
			let newSpot = Spot(
				id: spot.id,
				name: spot.name,
				activityType: Spot.ActivityType.Static(spot.address!, newRecurrences),
				location: spot.location,
				priest: spot.priest
			)
			spots[spotID] = newSpot
		}
		return Array(spots.values)
	}

	// MARK: - Editing Spot's Recurrence

	func setRecurrence(startAt startAt: Time, stopAt: Time,
					   at schedule: Recurrence.Schedule,
					   completion: Result<Recurrence, NSError> -> Void) {
		if recurrence == nil {
			createRecurrence(startAt: startAt, stopAt: stopAt,
			                 at: schedule, completion: completion)
		} else {
			updateRecurrence(startAt: startAt, stopAt: stopAt,
			                 at: schedule, completion: completion)
		}
	}
	
	private func createRecurrence(startAt startAt: Time, stopAt: Time,
	                           	  at schedule: Recurrence.Schedule,
	                              completion: Result<Recurrence, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/recurrences/create.html
		let priest = User.currentPriest!
		let createRecurrenceURL = "\(App.serverAPI)/spots/\(spot.id)/recurrences"
		let params: [String: AnyObject] = [
			"access_token": priest.oauth.accessToken,
			"recurrence": jsonRecurrence(startAt, stopAt, schedule)
		]
		Alamofire.request(.POST, createRecurrenceURL, parameters: params).responseJSON {
			response in
			switch response.result {
			case .Success(let data):
				self.recurrence = Recurrence(fromJSON: JSON(data))!
				completion(.Success(self.recurrence!))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	private func updateRecurrence(startAt startAt: Time, stopAt: Time,
								  at schedule: Recurrence.Schedule,
	                              completion: Result<Recurrence, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/recurrences.html#description-update
		let priest = User.currentPriest!
		let updateRecurrenceURL = "\(App.serverAPI)/recurrences/\(recurrence!.id)"
		let params: [String: AnyObject] = [
			"access_token": priest.oauth.accessToken,
			"recurrence": jsonRecurrence(startAt, stopAt, schedule)
		]
		Alamofire.request(.PATCH, updateRecurrenceURL, parameters: params).responseJSON {
			response in
			switch response.result {
			case .Success(let data):
				let json = JSON(data).dictionary!
				precondition(json["result"] == "success")
				self.recurrence = Recurrence(
					id: self.recurrence!.id, spotID: self.spot.id,
					startAt: startAt, stopAt: stopAt, at: schedule)
				completion(.Success(self.recurrence!))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	private func jsonRecurrence(startAt: Time, _ stopAt: Time,
	                            _ schedule: Recurrence.Schedule) -> [String: AnyObject] {
		var recurrence: [String: AnyObject] = [
			"start_at": startAt.toJSON().description,
			"stop_at":  stopAt.toJSON().description
		]
		switch schedule {
		case .SingleDate(let date):
			recurrence["date"] = date.toJSON().description
		case .Weekly(let weekdays):
			recurrence["week_days"] = weekdays.map { $0.toJSON().description }
		}
		return recurrence
	}
	
	func deleteRecurrence(completion: Result<Void, NSError> -> Void) {
		precondition(recurrence != nil)
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/recurrences.html
		let priest = User.currentPriest!
		let deleteURL = "\(App.serverAPI)/recurrences/\(recurrence!.id)"
		let params: [String: AnyObject] = [
			"access_token": priest.oauth.accessToken
		]
		Alamofire.request(.DELETE, deleteURL, parameters: params).responseString {
			response in
			switch response.result {
			case .Success(let data):
				precondition(data.isEmpty)
				self.recurrence = nil
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
}
