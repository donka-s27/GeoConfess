//
//  UserBot.swift
//  GeoConfess
//
//  Created by Donka on June 14, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import SwiftyJSON

// MARK: - User Bot Protocol

/// Protocol for interacting with bots.
/// This mini framework paves the way for full-blown test bots in the future.
protocol UserBotProtocol {

	/// Runs the bot and returns the next notification.
	/// Returns nil if bot processing has ended.
	func nextNotificationFromBot() -> Notification?
}

// MARK: - User Bot

/// Superclass for user bots used in test mode.
class UserBot {
	
	private static var nextBotKey: UInt = 0
	private static var nextBotID: ResourceID          = 100_000
	private static var nextMeetRequestID: ResourceID  = 100_000
	private static var nextMessageID: ResourceID      = 100_000
	private static var nextNotificationID: ResourceID = 100_000
	
	private let id: ResourceID
	private let userInfo: UserInfo
	
	private init(botWithRole role: User.Role) {
		self.id = UserBot.nextBotID
		
		let prefix  = role.rawValue.stringWithUppercaseFirstCharacter
		let botName = "\(prefix)_Bot_\(UserBot.nextBotKey)"
		self.userInfo = UserInfo(id: id, name: botName, surname: "Bot")
		
		UserBot.nextBotKey += 1
		UserBot.nextBotID  += 1
	}

	private func jsonEncodingDecodingForNotification(json: JSON) -> Notification {
		let jsonString = json.description
		let jsonStringBytes = jsonString.dataUsingEncoding(
			NSUTF8StringEncoding, allowLossyConversion: false)!
		return FakeNotification(fromJSON: JSON(data: jsonStringBytes))!
	}
	
	private func messageTo(recipientID: ResourceID, text: String) -> JSON {
		let now = Message.dateFormatter.stringFromDate(NSDate())
		let message: [String: JSON] = [
			"id":           JSON(UserBot.nextMessageID),
			"sender_id":    JSON(id),
			"recipient_id": JSON(recipientID),
			"text":         JSON(text),
			"created_at":   JSON(now),
			"updated_at":   JSON(now)
		]
		UserBot.nextMessageID += 1
		return JSON(message)
	}
	
	private func notificationAbout(action: Notification.Action,
	                               forMeetRequest meetRequest: JSON) -> Notification {
		let notification: [String: JSON] = [
			"id":           JSON(UserBot.nextNotificationID),
			"unread":       true,
			"model":        "MeetRequest",
			"action":       JSON(action),
			"meet_request": meetRequest
		]
		UserBot.nextNotificationID += 1
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
	
	private func notificationAbout(action: Notification.Action,
	                               forMessage message: JSON) -> Notification {
		let notification: [String: JSON] = [
			"id":      JSON(UserBot.nextNotificationID),
			"unread":  true,
			"model":   "Message",
			"action":  JSON(action),
			"message": message
		]
		UserBot.nextNotificationID += 1
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
}

// MARK: - PriestBot Class

/// A simple priest bot.
final class PriestBot: UserBot, UserBotProtocol {
	
	private unowned let penitent: User
	private let meetRequestID: ResourceID
	private var meetStatus: MeetRequest.Status?
	private var messageCount = 0
	
	/// Creates bot for interacting with the specified user.
	init(toMeetWith penitent: User) {
		self.penitent = penitent
		self.meetRequestID = UserBot.nextMeetRequestID
		UserBot.nextMeetRequestID += 1
		super.init(botWithRole: .Priest)
	}
	
	func nextNotificationFromBot() -> Notification? {
		guard meetStatus != nil else {
			meetStatus = .Pending
			return notificationAbout(.Sent, forMeetRequest: meetRequest)
		}
		switch meetStatus! {
		case .Pending:
			let action: Notification.Action
			if randomBool() {
				meetStatus = .Accepted
				action = .Accepted
			} else {
				meetStatus = .Refused
				action = .Refused
			}
			return notificationAbout(action, forMeetRequest: meetRequest)
		case .Accepted:
			guard randomDouble() >= 0.20 else { return nil }
			let message = messageTo(penitent.id,
			                        text: "Priest says hello (\(messageCount))")
			messageCount += 1
			return notificationAbout(.Received, forMessage: message)
		case .Refused:
			return nil
		}
	}
	
	private var meetRequest: JSON {
		let meetRequest: [String: JSON] = [
			"id":       JSON(meetRequestID),
			"penitent": JSON(["id": JSON(penitent.id)]),
			"priest":   userInfo.toJSON(),
			"status":   JSON(meetStatus!)
		]
		return JSON(meetRequest)
	}
}

// MARK: - PenitentBot Class

/// A simple penitent bot.
final class PenitentBot: UserBot, UserBotProtocol {

	private unowned let priest: Priest
	private let meetRequestID: ResourceID
	private var meetStatus: MeetRequest.Status?
	
	// TODO: Implement PenitentBot class.
	
	/// Creates bot for interacting with the specified priest.
	init(toMeetWith priest: Priest) {
		self.priest = priest
		self.meetRequestID = UserBot.nextMeetRequestID
		UserBot.nextMeetRequestID += 1
		super.init(botWithRole: .Priest)
	}
	
	func nextNotificationFromBot() -> Notification? {
		guard meetStatus != nil else {
			meetStatus = .Pending
			return notificationAbout(.Sent, forMeetRequest: meetRequest)
		}
		switch meetStatus! {
		case .Pending:
			let action: Notification.Action
			if randomBool() {
				meetStatus = .Accepted
				action = .Accepted
			} else {
				meetStatus = .Refused
				action = .Refused
			}
			return notificationAbout(action, forMeetRequest: meetRequest)
		case .Accepted, .Refused:
			return nil
		}
	}
	
	private var meetRequest: JSON {
		let meetRequest: [String: JSON] = [
			"id":       JSON(meetRequestID),
			"penitent": userInfo.toJSON(),
			"priest":   JSON(["id": JSON(priest.id)]),
			"status":   JSON(meetStatus!)
		]
		return JSON(meetRequest)
	}
}

// MARK: - BotSet Class

/// Manages a *dynamically* increasing bot set.
final class UserBotSet {
	
	init(maxBotCount: UInt = UInt.max, createBot: (botIndex: UInt) -> UserBotProtocol) {
		self.maxBotCount = maxBotCount
		self.createBot = createBot
	}
	
	convenience init(maxBotCount: UInt = UInt.max, createBot: () -> UserBotProtocol) {
		let createBotWithIndex: (botIndex: UInt) -> UserBotProtocol = {
			botIndex in
			return createBot()
		}
		self.init(maxBotCount: maxBotCount, createBot: createBotWithIndex)
	}

	private var activeBots = [UserBotProtocol]()
	private let createBot: (botIndex: UInt) -> UserBotProtocol
	
	private let maxBotCount: UInt
	private var botsCreated: UInt = 0
	
	func nextNotificationFromBots() -> Notification? {
		while activeBots.count > 0 || botsCreated < maxBotCount {
			let selectedBot = randomIntInRange(0...activeBots.count)
			// Should we create a new bot?
			if selectedBot == activeBots.count && botsCreated < maxBotCount {
				let newBot = createBot(botIndex: botsCreated)
				botsCreated += 1
				activeBots.append(newBot)
				let firstNotification = newBot.nextNotificationFromBot()
				precondition(firstNotification != nil)
				return firstNotification
			}
			// Runs an existing bot.
			let bot = activeBots[selectedBot]
			if let notification = bot.nextNotificationFromBot() {
				return notification
			}
			activeBots.removeAtIndex(selectedBot)
		}
		return nil
	}
	
	var botCount: Int {
		return activeBots.count
	}
}
