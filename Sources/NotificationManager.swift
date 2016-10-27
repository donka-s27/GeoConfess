//
//  NotificationManager.swift
//  GeoConfess
//
//  Created  by Dan on April 30, 2016.
//  Reviewed by Dan Dobrev on May 31, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Manages all notifications received by the user.
/// Entry point available at `User.current.notifications`.
final class NotificationManager: Observable, AppObserver {

	// MARK: - NotificationManager Lifecyle
	
	private weak var user: User!
	
	init() {
		/* empty */
	}

	func bindUser(user: User) {
		precondition(self.user == nil)
		self.user = user
		App.instance.addObserver(self)
		initNotificationsPolling()
		initFakeNotificationsSpawner()
	}

	deinit {
		App.instance.removeObserver(self)
		stopFetchingNotifications()
	}
	
	func startFetchingNotifications() {
		startNotificationsPolling()
		startFakeNotificationsSpawner()
	}
	
	func stopFetchingNotifications() {
		stopNotificationsPolling()
		stopFakeNotificationsSpawner()
	}

	func applicationDidUpdateConfiguration(config: App.Configuration) {
		stopFetchingNotifications()
		removeAllPolledNotifications()
		removeAllCachedMeetRequests()
		removeAllCachedMessages()
		removeAllFakeNotificationsSpawner()
		startFetchingNotifications()
	}

	// MARK: - Updating Notifications

	/// Last 99 *raw* notifications of current user not older than 1 month.
	///
	/// The notifications are sorted in *chronological* order (ie, newest comes last).
	private(set) var notifications: [Notification] = [ ] {
		didSet {
			notifications.sortInPlace()
			let inserted = Set(notifications).subtract(oldValue)
			let deleted  = Set(oldValue).subtract(notifications)
			addMeetRequestsFromNewNotifications(inserted)
			addMessagesFromNewNotifications(inserted)
			if inserted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didAddNotifications: inserted.sort())
				}
			}
			if deleted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didDeleteNotifications: deleted.sort())
				}
			}
		}
	}
	
	private var notificationsPollingTimer: Timer?
	
	private var notificationsRefreshRate: NSTimeInterval {
		let key = "Notifications Refresh Rate (seconds)"
		let refreshRate = (App.instance.properties[key]! as! NSNumber).doubleValue
		assert(refreshRate > 0)
		return refreshRate
	}

	private func initNotificationsPolling() {
		/* empty */
	}

	private func startNotificationsPolling() {
		let polling = "Starting notifications polling"
		log("\(polling)...")
		stopNotificationsPolling()
		updateNotificationsCache()
		log("\(polling)...OK")
	}
	
	private func stopNotificationsPolling() {
		notificationsPollingTimer?.dispose()
		notificationsPollingTimer = nil
	}
	
	private func removeAllPolledNotifications() {
		let resetting = "Resetting notifications polling"
		log("\(resetting)...")
		let oldCount = notifications.count
		notifications.removeAll()
		notificationsAlreadyReturned.removeAll()
		log("\(resetting)...OK (\(oldCount) deleted)")
	}
	
	private func updateNotificationsCache(completion: (() -> Void)? = nil) {
		preconditionIsMainQueue()
		let updating = "Updating notifications"
		log("\(updating)...")
		
		func scheduleNextUpdate(interval: Double, completion: (() -> Void)?) {
			notificationsPollingTimer = Timer.scheduledTimerWithTimeInterval(interval) {
				[weak self] in
				self?.updateNotificationsCache(completion)
			}
		}
		
		getNewNotifications() {
			result in
			preconditionIsMainQueue()
			switch result {
			case .Success(let newNotifications):
				let reqCount = newNotifications.meetRequestCount
				let msgCount = newNotifications.messageCount
				log("\(updating)... OK (\(reqCount) meet reqs, \(msgCount) messages)")
                self.notifications += newNotifications
				scheduleNextUpdate(self.notificationsRefreshRate, completion: nil)
				completion?()
			case .Failure(let error):
				let wait = randomDoubleInRange(3...8)
				logError("\(updating)... FAILED. " +
					"Will try again in \(wait) seconds...\n\(error)")
				scheduleNextUpdate(wait, completion: completion)
			}
		}
	}
	
	func didReceivePushNotification(id: ResourceID, with action: Notification.Action,
	                                completion: Result<Notification, Error> -> Void) {
		preconditionIsMainQueue()
		stopNotificationsPolling()
		updateNotificationsCache {
			let pushedNotification = self.notifications.filter { $0.id == id }.first
			guard pushedNotification != nil else {
				completion(.Failure(Error(code: .restObjectNotFound)))
				return
			}
			self.notifyObservers {
				$0.notificationManager(
					self, didReceivePushNotification: pushedNotification!)
			}
			completion(.Success(pushedNotification!))
		}
	}

	func didReceivePushNotification(pushedNotification: PriestAvailabilityNotification,
	                                completion: Result<Void, NSError> -> Void) {
		self.notifyObservers {
			$0.notificationManager(
				self, didReceivePushNotification: pushedNotification)
		}
		completion(.Success())
	}

	// MARK: - Meet Requests
	
	private var meetRequestsByID = [ResourceID: MeetRequest]()
	
	/// All latest meet requests.
	var meetRequests: Set<MeetRequest> {
		return Set(meetRequestsByID.values)
	}

	func meetRequestForPriest(priestID: ResourceID) -> MeetRequest? {
		for meetRequest in meetRequests {
			if meetRequest.priest.id == priestID {
				return meetRequest
			}
		}
		return nil
	}
	
	func latestNotificationAbout(meetRequest: MeetRequest) -> Notification? {
		for notification in notifications.userLevelNotifications() {
			switch notification.model {
			case .MeetRequestNotification(let someMeetRequest):
				if someMeetRequest.id == meetRequest.id {
					return notification
				}
			case .MessageNotification:
				break
			}
		}
		return nil
	}
	
	private func removeAllCachedMeetRequests() {
		meetRequestsByID.removeAll()
	}

	private func addMeetRequestsFromNewNotifications(notifications: Set<Notification>) {
		var latest = [ResourceID: MeetRequest]()
		for notification in notifications.sort().reverse() {
			switch notification.model {
			case .MeetRequestNotification(let meetRequest):
				if latest[meetRequest.id] == nil {
					latest[meetRequest.id] = meetRequest
				}
			case .MessageNotification:
				break
			}
		}
		for (id, meetRequest) in latest {
			meetRequestsByID[id] = meetRequest
		}
		return
	}

	/// Sends a meet request to the specified priest.
	func sendMeetRequestTo(priestID: ResourceID,
	                       completion: Result<MeetRequest, Error> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/meet_requests/create.html
		let createRequestURL = "\(App.serverAPI)/requests"
		let request: [String: AnyObject] = [
			"priest_id": NSNumber(unsignedLongLong: priestID),
			"latitude":  user.location!.coordinate.latitude,
			"longitude": user.location!.coordinate.longitude
		]
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
			"request": request
		]
		let httpRequest = Alamofire.request(.POST, createRequestURL, parameters: params)
		httpRequest.validate().responseJSON {
			response in
			preconditionIsMainQueue()
			switch response.result {
			case .Success(let value):
				let meetRequest = MeetRequest(fromJSON: JSON(value))!
				precondition(self.meetRequestsByID[meetRequest.id] == nil)
				self.meetRequestsByID[meetRequest.id] = meetRequest
				completion(.Success(meetRequest))
			case .Failure(let error):
				completion(.Failure(Error(causedBy: error)))
			}
		}
	}
	
	// MARK: - Messages

	private var messagesByID = [ResourceID: Message]() {
		didSet {
			let inserted = Set(messagesByID.values).subtract(oldValue.values)
			if inserted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didAddMessages: inserted.sort())
				}
			}
		}
	}

	/// All messages *sent* or *received* by this user *ever*.
	///
	/// The messages are sorted in *chronological* order (ie, newest comes last).
	var messages: [Message] {
		return messagesByID.values.sort()
	}
	
	/// Lookup the user info for the specified ID.
	func userFromID(id: ResourceID) -> UserInfo? {
		for meetRequest in meetRequests {
			for user in [meetRequest.penitent, meetRequest.priest] {
				if user.id == id {
					return user
				}
			}
		}
		return nil
	}
	
	private func removeAllCachedMessages() {
		messagesByID.removeAll()
		getAllUserMessages()
	}
	
	private func addMessagesFromNewNotifications(notifications: Set<Notification>) {
		var latest = [ResourceID: Message]()
		for notification in notifications.sort().reverse() {
			switch notification.model {
			case .MessageNotification(let message):
				if latest[message.id] == nil {
					latest[message.id] = message
				}
			case .MeetRequestNotification:
				break
			}
		}
		for (id, message) in latest {
			messagesByID[id] = message
		}
		return
	}
	
	/// Downloads the *complete* chat history for this user.
	private func getAllUserMessages() {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/messages/index.html
		let userMessgesURL = "\(App.serverAPI)/messages"
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
		]
		let getting = "Getting all messages"
		log("\(getting)...")
		Alamofire.request(.GET, userMessgesURL, parameters: params).responseJSON {
			[weak self] response in
			preconditionIsMainQueue()
			guard self != nil else { return }
			switch response.result {
			case .Success(let data):
				let messageArrayJSON = JSON(data).array!
				for messageJSON in messageArrayJSON {
					let message = Message(fromJSON: messageJSON)!
					if let storedMessage = self!.messagesByID[message.id] {
						precondition(storedMessage == message)
					} else {
						self!.messagesByID[message.id] = message
					}
				}
				log("\(getting)... OK (\(messageArrayJSON.count) downloaded)")
			case .Failure(let error):
				logError("\(getting)... FAILED (\(error))")
			}
		}
	}
	
	/// Sends a message to the specified user.
	func sendMessageTo(userID: ResourceID, text: String,
	                   completion: Result<Message, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/messages/create.html
		let createMessageURL = "\(App.serverAPI)/messages"
		let message: [String: AnyObject] = [
			"sender_id":    NSNumber(unsignedLongLong: user.id),
			"recipient_id": NSNumber(unsignedLongLong: userID),
			"text":         text
		]
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
			"message": message
		]
		Alamofire.request(.POST, createMessageURL, parameters: params).responseJSON {
			[weak self] response in
			guard self != nil else { return }
			switch response.result {
			case .Success(let data):
				guard let sentMessage = Message(fromJSON: JSON(data)) else {
					completion(.Failure(JSON(data).nserror()))
					return
				}
				precondition(self!.messagesByID[sentMessage.id] == nil)
				self!.messagesByID[sentMessage.id] = sentMessage
				completion(.Success(sentMessage))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	// MARK: - Observing Notifications
	
	/// Observers list. The actual type is `ObserverSet<NotificationObserver>`.
	private var notificationObservers = ObserverSet()
	
	func addObserver(observer: NotificationObserver) {
		notificationObservers.addObserver(observer)
	}
	
	func removeObserver(observer: NotificationObserver) {
		notificationObservers.removeObserver(observer)
	}
	
	/// Fires notification to observers.
	private func notifyObservers(notify: (NotificationObserver) -> Void) {
		notificationObservers.notifyObservers {
			notify($0 as! NotificationObserver)
		}
	}

	// MARK: - Fake Notifications from Bots

	private var fakePriests: UserBotSet?
	private var fakePenitents: UserBotSet?
	private var newFakeNotifications = [Notification]()
	private var fakeNotificationsTimer: Timer?
	
	private func initFakeNotificationsSpawner() {
		if priestBotsEnabled {
			fakePriests = UserBotSet { PriestBot(toMeetWith: self.user) }
		}
		if penitentBotsEnabled, let priest = user as? Priest {
			fakePenitents = UserBotSet { PenitentBot(toMeetWith: priest) }
		}
	}
	
	private func removeAllFakeNotificationsSpawner() {
		newFakeNotifications.removeAll()
		fakePriests = nil
		fakePenitents = nil
	}
	
	private func startFakeNotificationsSpawner() {
		stopFakeNotificationsSpawner()
		guard fakePriests != nil || fakePenitents != nil else { return }
		fakeNotificationsTimer = Timer.scheduledTimerWithTimeInterval(0.25) {
			[weak self] in
			self?.generateFakeNotification()
		}
	}
	
	private func stopFakeNotificationsSpawner() {
		fakeNotificationsTimer?.dispose()
		fakeNotificationsTimer = nil
	}

	private var priestBotsEnabled: Bool {
		let key = "Fake Notifications to/from Priest Bots"
		let enabled = (App.instance.properties[key]! as! NSNumber).boolValue
		return enabled
	}

	private var penitentBotsEnabled: Bool {
		let key = "Fake Notifications to/from Penitent Bots"
		let enabled = (App.instance.properties[key]! as! NSNumber).boolValue
		return enabled
	}

	private var fakeNotificationsSpawnRate: NSTimeInterval {
		let key = "Fake Notifications Mean Spawn Rate (seconds)"
		let spawnRate = (App.instance.properties[key]! as! NSNumber).doubleValue
		assert(spawnRate >= 0)
		let minRate = max(spawnRate - 3, 0.1)
		let maxRate = spawnRate + 3
		return randomDoubleInRange(minRate...maxRate)
	}
	
	/// Generate a single fake notification.
	/// We do it from JSON to improve test coverage.
	private func generateFakeNotification() {
		preconditionIsMainQueue()
		let generating = "Generating fake notifications"
		log("\(generating)...")
		
		var botCount = 0
		for userBots in [fakePriests, fakePenitents] where userBots != nil {
			if let fakeNotification = userBots!.nextNotificationFromBots() {
				newFakeNotifications.append(fakeNotification)
			}
			botCount += userBots!.botCount
		}
		let randomRate = fakeNotificationsSpawnRate
		fakeNotificationsTimer = Timer.scheduledTimerWithTimeInterval(randomRate) {
			[weak self] in
			self?.generateFakeNotification()
		}
		
		log("\(generating)... OK (\(newFakeNotifications.count) new, \(botCount) bots)")
	}

	/*
	
	private var nextFakeNotificationID: ResourceID = 100_000
	private var nextFakeMeetRequestID:  ResourceID = 100_000
	private var nextFakeMessgeID:       ResourceID = 100_000
	
	/// Generate a single fake notification.
	/// We do it from JSON to improve test coverage.
	private func generateFakeNotification() {
		preconditionIsMainQueue()
		let logLabel = "Generating fake notifications"
		log("\(logLabel)...")
		
		var fakeNotification: Notification! = nil
		repeat {
			switch randomIntInRange(0...4) {
			case 0:  fakeNotification = fakeMeetRequestAt(.Sent)
			case 1:  fakeNotification = fakeMeetRequestAt(.Received)
			case 2:  fakeNotification = fakeMeetRequestAt(.Accepted)
			case 3:  fakeNotification = fakeMeetRequestAt(.Refused)
			case 4:  fakeNotification = fakeMessage()
			default: preconditionFailure("Should never happen!")
			}
		} while fakeNotification == nil
		
		newFakeNotifications.append(fakeNotification!)
		let rate = NotificationManager.fakeNotificationsSpawnRate
		fakeNotificationsSpawnTimer = Timer
			.scheduledTimerWithTimeInterval(rate) {
				[weak self] in
				self?.generateFakeNotification()
		}
		log("\(logLabel)... OK (\(newFakeNotifications.count) new)")
	}

	private func fakeMeetRequestAt(action: Notification.Action) -> Notification? {
		let status: MeetRequest.Status
		switch action {
		case .Sent:
			status = .Pending // A priest can also be a penitent.
		case .Received:
			guard user.role == .Priest else { return nil }
			status = .Pending
		case .Accepted:
			status = .Accepted
		case .Refused:
			status = .Refused
		}
		
		// Fake **meet request**.
		var meetRequest = [String: JSON]()
		meetRequest["id"] = JSON(nextFakeMeetRequestID)
		meetRequest["status"] = JSON(status.rawValue)
		switch action {
		case .Sent, .Accepted, .Refused:
			meetRequest["penitent"] = JSON(["id": JSON(user.id)])
			meetRequest["priest"] = JSON([
				"id":      123_456,
				"name":    "Fake_Priest",
				"surname": "Fakey"]
			)
		case .Received:
			assert(user.role == .Priest)
			meetRequest["priest"] = JSON(["id": JSON(user.id)])
			meetRequest["penitent"] = JSON([
				"id":      123_456_789,
				"name":    "Fake_Penitent",
				"surname": "Fakey"]
			)
		}
		nextFakeMeetRequestID  += 1
		
		// Fake **notification**.
		let notification: [String: JSON] = [
			"id":           JSON(nextFakeNotificationID),
			"unread":       true,
			"model":        "MeetRequest",
			"action":       JSON(action.rawValue),
			"meet_request": JSON(meetRequest)
		]
		nextFakeNotificationID += 1
		
		// We do a *full* JSON serialization to stress test our code.
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
	
	private func fakeMessage() -> Notification {
		// Fake **message**.
		let now = Message.dateFormatter.stringFromDate(NSDate())
		let message: [String: JSON] = [
			"id":           JSON(nextFakeMessgeID),
			"sender_id":    123_456,
			"recipient_id": JSON(user.id),
			"text":         "Hello from outer space!",
			"created_at":   JSON(now),
			"updated_at":   JSON(now)
		]
		nextFakeMessgeID += 1
		
		// Fake **notification**.
		let notification: [String: JSON] = [
			"id":      JSON(nextFakeNotificationID),
			"unread":  true,
			"model":   "Message",
			"action":  "received",
			"message": JSON(message)
		]
		nextFakeNotificationID += 1
		
		// We do a *full* JSON serialization to stress test our code.
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
	*/
	
	// MARK: - Fetching New Notifications
	
	/// Fetches new *real* and *fake* user notifications from the server.
	private func getNewNotifications(completion: Result<[Notification], Error> -> Void) {
		getAllNotifications(forUser: user) {
			[weak self] result in
			guard self != nil else { return }
			preconditionIsMainQueue()
			switch result {
			case .Success(let allNotifications):
				let newNotifications = self!.filterNewNotifications(
					allNotifications + self!.newFakeNotifications)
				self!.newFakeNotifications.removeAll()
				completion(.Success(newNotifications))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	private var notificationsAlreadyReturned = Set<ResourceID>()
	
	private func filterNewNotifications(all: [Notification]) -> [Notification] {
		var newNotifications = [Notification]()
		for notification in all {
			if !notificationsAlreadyReturned.contains(notification.id) {
				notificationsAlreadyReturned.insert(notification.id)
				newNotifications.append(notification)
			}
		}
		return newNotifications
	}
}

// MARK: - NotificationManager Observer Protocol

/// User model events.
protocol NotificationObserver: class, Observer {

	/// New notifications were inserted.
	func notificationManager(manager: NotificationManager,
	                         didAddNotifications notifications: [Notification])
	
	/// Old notifications were deleted.
	func notificationManager(manager: NotificationManager,
	                         didDeleteNotifications notifications: [Notification])
	
	/// New messages were received (or sent).
	func notificationManager(manager: NotificationManager,
	                         didAddMessages messages: [Message])

	/// Received new push notification.
	func notificationManager(manager: NotificationManager,
	                         didReceivePushNotification notification: Notification)

	/// Received new push notification.
	func notificationManager(manager: NotificationManager, didReceivePushNotification
							 notification: PriestAvailabilityNotification)
}

// MARK: - Utility Functions

/// Fetches all user notifications from the server.
private func getAllNotifications(forUser user: User,
								 completion: Result<[Notification], Error> -> Void) {
	// The corresponding API is documented here:
	// https://geoconfess.herokuapp.com/apidoc/V1/notifications
	let getNotificationsURL = "\(App.serverAPI)/notifications"
	let params: [String: AnyObject] = [
		"access_token": user.oauth.accessToken
	]
	let httpRequest = Alamofire.request(.GET, getNotificationsURL, parameters: params)
	httpRequest.validate().responseJSON {
		response in
		switch response.result {
		case .Success(let value):
			var notifications = [Notification]()
			for notification in JSON(value).array! {
				let notification = Notification(fromJSON: notification)!
				notifications.append(notification)
			}
			completion(.Success(notifications))
		case .Failure(let error):
			completion(.Failure(Error(causedBy: error)))
		}
	}
}

// MARK: - Notification Sequence

extension SequenceType where Generator.Element: Notification {
	
	/// Returns a notifications `Set` with only the
	/// _lastest_ update per notifiable object.
	///
	/// For instance, this is the set presented by the notifications UI.
	func latestNotificationsPerObject() -> Set<Notification> {
		var latestUpdate = [ResourceID: Notification]()
		for notification in self.sort().reverse() {
			let notifiableID: ResourceID
			switch notification.model {
			case .MeetRequestNotification(let meetRequest):
				notifiableID = meetRequest.id
			case .MessageNotification(let message):
				notifiableID = message.senderID
			}
			if latestUpdate[notifiableID] == nil {
				latestUpdate[notifiableID] = notification
			}
		}
		return Set(latestUpdate.values)
	}
	
	/// Returns a notifications `Array` sorted in 
	/// *chronological* order (ie, latest notification comes last).
	func chronologicalOrder() -> [Notification] {
		return self.sort()
	}
	
	/// Returns unread notifications count.
	var unreadCount: Int {
		return self.filter { $0.unread }.count
	}
	
	/// Returns the total of *meet request* related notifications.
	var meetRequestCount: Int {
		return self.filter {
			switch $0.model {
			case .MeetRequestNotification:
				return true
			default:
				return false
			}
		}.count
	}

	/// Returns the total of *message* related notifications.
	var messageCount: Int {
		return self.filter {
			switch $0.model {
			case .MessageNotification:
				return true
			default:
				return false
			}
		}.count
	}
}
