//
//  NotificationsViewController.swift
//  GeoConfess
//
//  Created  by Dan on April 19, 2016.
//  Reviewed by Dan Dobrev on June 2, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the notifications UI.
final class NotificationsViewController: AppViewControllerWithToolbar,
										 UITableViewDataSource, UITableViewDelegate {

	// MARK: - View Controller Lifecycle
	
	static func instantiateViewController() -> NotificationsViewController {
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		return storyboard.instantiateViewControllerWithIdentifier(
			"NotificationsViewController") as! NotificationsViewController
	}
	
	override func viewDidLoad(){
		super.viewDidLoad()
		
		notificationsTable.delegate = self
		notificationsTable.dataSource = self
		notificationsTable.tableFooterView = UIView()
	}
 
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		markAsReandOnExit.removeAll()
		let notificationManager = User.current.notificationManager
		notifications = notificationManager.notifications.userLevelNotifications()
		notificationManager.addObserver(self)
		notificationsTable.reloadData()
		notificationsTable.selectRowAtIndexPath(nil, animated: false,
		                                        scrollPosition: .None)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		
		if let user = User.current {
			user.notificationManager.removeObserver(self)
			for notification in markAsReandOnExit {
				notification.markAsReadAndIgnoreError()
			}
			markAsReandOnExit.removeAll()
		}
	}
	
	// MARK: - Notifications Model
	
	private var notifications = [Notification]() {
		didSet {
			assert(notifications == notifications.userLevelNotifications())
		}
	}
	
	override func notificationManager(
		manager: NotificationManager,
		didAddNotifications notifications: [Notification]) {
		super.notificationManager(manager, didAddNotifications: notifications)
		notificationsDidUpdate(manager.notifications)
	}
	
	override func notificationManager(
		manager: NotificationManager,
		didDeleteNotifications notifications: [Notification]) {
		super.notificationManager(manager, didDeleteNotifications: notifications)
		notificationsDidUpdate(manager.notifications)
	}

	private func notificationsDidUpdate(rawNotifications: [Notification]) {
		let oldNotifications = self.notifications
		let newNotifications = rawNotifications.userLevelNotifications()
		
		// Try to insert new notifications in a fast & smooth way, if easy.
		// If too tricky, lets just reload the damn thing!
//		if !insertNewNotifications(currentNotifications, old: oldNotifications) {
//			notificationsTable.reloadData()
//		}
		
		reloadNotifications(newNotifications, old: oldNotifications)
		
		/*
		if currentNotifications.count < 5 {
			notificationsTable.reloadData()
		} else {
			print("-----------------------------------")
			//count = count == nil ? 3 : count! - 1
			count = 4
			notificationsTable.beginUpdates()
			notificationsTable.moveRowAtIndexPath(row(0), toIndexPath: row(1))
			notificationsTable.moveRowAtIndexPath(row(1), toIndexPath: row(0))
			notificationsTable.reloadRowsAtIndexPaths([row(2)], withRowAnimation: .Left)
//			notificationsTable.deleteRowsAtIndexPaths(
//				[NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Left)
			notificationsTable.endUpdates()
		}
		*/

		/*
		// Makes sure latest notification is visible.
		if currentNotifications.count > 0 {
			let latestIndex = NSIndexPath(forRow: 0, inSection: 0)
			notificationsTable.scrollToRowAtIndexPath(
				latestIndex, atScrollPosition: .None, animated: true)
		}
		*/
	}
	
	/// Reloads updated notifications using animations.
	///
	/// Deletion, moving, and reloading operations within an animation block specify
	/// which rows in the *original* table should be removed, moved or reloaded;
	/// insertions specify which rows should be added to the *resulting* table.
	/// The index paths used to identify rows follow this model.
	///
	/// Inserting or removing an item in a mutable array, on the other hand, 
	/// *may* affect the array index used for the successive insertion or removal 
	/// operation; for example, if you insert an item at a certain index, the 
	/// indexes of all subsequent items in the array are incremented.
	private func reloadNotifications(newNotifications: [Notification],
	                                 old oldNotifications: [Notification]) {
		self.notifications = newNotifications
		var deleted  = Set(oldNotifications)
		var inserted = Set(newNotifications)
		
		func row(row: Int) -> NSIndexPath {
			return NSIndexPath(forRow: row, inSection: 0)
		}
		let table = notificationsTable!
		notificationsTable.beginUpdates()
		
		// Animates *updated* notifications.
		for (oldIndex, old) in oldNotifications.enumerate() {
			var newIndex: Int!
			var updatedRow = false
			for (index, new) in newNotifications.enumerate() {
				switch (old.model, new.model) {
				case (.MeetRequestNotification(let a), .MeetRequestNotification(let b)):
					if a.id == b.id {
						newIndex = index
						updatedRow = a.status != b.status
					}
				case (.MessageNotification(let a), .MessageNotification(let b)):
					if a.senderID == b.senderID {
						newIndex = index
						updatedRow = a.id != b.id
					}
				default:
					break
				}
				if newIndex != nil { break }
			}
			guard newIndex != nil else { continue }
			if updatedRow {
				if oldIndex != newIndex {
					table.moveRowAtIndexPath(row(oldIndex), toIndexPath: row(newIndex))
					if let cell = table.cellForRowAtIndexPath(row(oldIndex)) {
						let new = newNotifications[newIndex]
						UIView.animateWithDuration(3.0) {
							(cell as! NotificationCell).setNotification(new)
							//cell.layoutIfNeeded()
						}
					}
				} else {
					table.reloadRowsAtIndexPaths(
						[row(oldIndex)], withRowAnimation: .Right)
				}
			}
			deleted.remove(oldNotifications[oldIndex])
			inserted.remove(newNotifications[newIndex])
		}
		assert(oldNotifications.count - deleted.count + inserted.count ==
			newNotifications.count)
		
		// Deletes *discarded* notifications.
		if deleted.count > 0 {
			print("--- DELETED \(deleted.count) ---")
			let deletedRows = deleted.map {
				row(oldNotifications.indexOf($0)!)
			}
			table.deleteRowsAtIndexPaths(deletedRows, withRowAnimation: .Bottom)
		}
		
		// Inserts *new* notifications.
		if inserted.count > 0 {
			print("--- INSERTED \(inserted.count) ---")
			let insertedRows = inserted.map {
				row(newNotifications.indexOf($0)!)
			}
			table.insertRowsAtIndexPaths(insertedRows, withRowAnimation: .Top)
		}
		
		notificationsTable.endUpdates()
	}
	
//	var count: Int?
	
	private func insertNewNotifications(newNotifications: [Notification],
	                                    old oldNotifications: [Notification]) -> Bool {
		let newNotificationSet = Set(newNotifications)
		let oldNotificationSet = Set(oldNotifications)

		func indexPathsUntil(rowCount: Int) -> [NSIndexPath] {
			var indexPaths = [NSIndexPath]()
			for index in 0..<rowCount {
				indexPaths.append(NSIndexPath(forRow: index, inSection: 0))
			}
			return indexPaths
		}

		if newNotificationSet == oldNotificationSet {
			return true
		}
		if newNotificationSet.isEmpty {
			notificationsTable.deleteRowsAtIndexPaths(
				indexPathsUntil(oldNotificationSet.count), withRowAnimation: .Bottom)
			return true
		}
		if oldNotificationSet.isEmpty {
			notificationsTable.insertRowsAtIndexPaths(
				indexPathsUntil(newNotificationSet.count), withRowAnimation: .Top)
			return true
		}
		if oldNotificationSet.isSubsetOf(newNotificationSet) {
			let diffNotificationSet = newNotificationSet.subtract(oldNotificationSet)
			let oldMaxID = oldNotificationSet.maxElement()!.id
			let newMinID = diffNotificationSet.minElement()!.id
			if newMinID > oldMaxID {
				notificationsTable.insertRowsAtIndexPaths(
					indexPathsUntil(diffNotificationSet.count), withRowAnimation: .Top)
				return true
			}
		}
		return false
	}
	
	// MARK: - Table View Delegate and Data
	
	@IBOutlet weak private var notificationsTable: UITableView!
	
	func tableView(tableView: UITableView,
	               heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return 80
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return notifications.count
		//return count ?? notifications.count
	}
	
	private var markAsReandOnExit = [Notification]()
	
	func tableView(tableView: UITableView,
	               cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(
			"NotificationCell", forIndexPath: indexPath) as! NotificationCell
		let notification = notifications[indexPath.row]
		cell.setNotification(notification)
		
		// Marks non-actionable notification as read.
		let user = User.current!
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent:
				switch meetRequest.status {
				case .Pending, .Accepted, .Refused:
					markAsReandOnExit.append(notification)
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending:
					break // The request needs a reply.
				case .Accepted, .Refused:
					markAsReandOnExit.append(notification)
				}
			case .Admin:
				preconditionFailure("Unexpected role")
			}
		case .MessageNotification:
			break // The message needs to be seen.
		}
		return cell
	}
	
	// MARK: - Notification Selection
	
	func tableView(tableView: UITableView,
	               willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		let user = User.current!
		let notification = notifications[indexPath.row]

		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent:
				switch meetRequest.status {
				case .Pending, .Accepted, .Refused:
					return indexPath // Always selectable.
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending, .Accepted:
					return indexPath
				case .Refused:
					return nil
				}
			case .Admin:
				preconditionFailure("Unexpected role")
			}
		case .MessageNotification:
			switch user.role {
			case .Penitent, .Priest, .Admin:
				return indexPath // Always selectable.
			}
		}
	}
	
	func tableView(tableView: UITableView,
	               didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let notification = notifications[indexPath.row]
		print("Notification:\n\(notification)")
		let user = User.current!
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent:
				switch meetRequest.status {
				case .Pending, .Refused:
					// Penitent lands on priest page for pending/refused request (5.2.2).
					meetRequest.showMeetRequest(from: notification, animated: true)
				case .Accepted:
					// Penitent lands on chat.
					meetRequest.chatWith(.Priest, from: notification, animated: true)
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending:
					// Priest lands on UI 8.2 (booking request flow).
					meetRequest.replyToMeetRequest(from: notification, animated: true)
				case .Accepted:
					// Priest lands on chat.
					meetRequest.chatWith(.Penitent, from: notification, animated: true)
				case .Refused:
					preconditionFailure("This notification should not be selectable")
				}
			case .Admin:
				preconditionFailure("Admin role not expected")
			}
		case .MessageNotification(let message):
			message.chatWithSender(from: notification, animated: true)
		}
	}

	/// Presents view controller for the received push notification.
	static func pushViewControllerForPushNotification(notification: Notification) {
		let user = User.current!
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent:
				switch meetRequest.status {
				case .Refused:
					meetRequest.showMeetRequest(from: notification, animated: false)
				case .Accepted:
					meetRequest.chatWith(.Priest, from: notification, animated: false)
				case .Pending:
					preconditionFailure("This notification should not be pushed")
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending:
					meetRequest.replyToMeetRequest(from: notification, animated: false)
				case .Accepted:
					meetRequest.chatWith(.Penitent, from: notification, animated: false)
				case .Refused:
					preconditionFailure("This notification should not be pushed")
				}
			case .Admin:
				preconditionFailure("Unexpected role")
			}
		case .MessageNotification(let message):
			message.chatWithSender(from: notification, animated: false)
		}
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		/* empty */
	}
	
	// MARK: - Toolbar Buttons
	
	override func notificatioButtonTapped(buttton: UIButton) {
		navigationController.popViewControllerAnimated(true)
	}
}

// MARK: - MeetRequest Extensions

extension MeetRequest {
	
	/// Presents the specified meet request view controller (*syntax sugar*).
	/// This notification type, when opened, should automatically be marked as read.
	func showMeetRequest(from notification: Notification, animated: Bool) {
		let user = User.current!
		let priestLocation = user.nearbySpots.priestDynamicSpot(priest.id)?.location
		MeetRequestViewController.showMeetRequestWithPriest(
			self, priestLocation: priestLocation, animated: animated)
		notification.markAsReadAndIgnoreError()
	}
	
	/// Set ups chatting with the specified user (*syntax sugar*).
	func chatWith(sender: User.Role, from notification: Notification?, animated: Bool) {
		ChatViewController.chatWithUser(self.userWithRole(sender), animated: animated)
		notification?.markAsReadAndIgnoreError()
	}
	
	/// Set ups replying to the specified meet request (*syntax sugar*).
	func replyToMeetRequest(from notification: Notification, animated: Bool) {
		MeetRequestReplyViewController.replyToMeetRequest(self, animated: animated) {
			replied in
			if replied {
				notification.markAsReadAndIgnoreError()
			}
		}
	}
}

// MARK: - Message Extensions

private extension Message {

	/// User always lands on chat after selecting/receiving a message.
	func chatWithSender(from messageNotification: Notification, animated: Bool) {
		let user = User.current!
		precondition(self.recipientID == user.id)
		ChatViewController.chatWithUser(self.sender, animated: animated)
		
		// We should mark this notifications and *all*
		// older ones, from this same sender, also as read.
		let olderMessages = user.notificationManager.notifications.filter {
			guard $0.id < messageNotification.id else { return false }
			switch $0.model {
			case .MessageNotification(let oldMessage):
				return oldMessage.senderID == self.senderID
			default:
				return false
			}
		}
		for unreadMessage in olderMessages + [messageNotification] {
			unreadMessage.markAsReadAndIgnoreError()
		}
	}
}

// MARK: - Notification Extensions

extension Notification {
	
	func markAsReadAndIgnoreError() {
		guard self.unread else { return }
		self.markAsRead() {
			result in
			switch result {
			case .Success:
				break
			case .Failure(let error):
				logError("Marking notification as read failed:\n\(error)")
			}
		}
	}
}

extension Message {
	
	/// Infers user information for this message sender.
	///
	/// This is might not always work.
	var sender: UserInfo {
		let notificationManager = User.current?.notificationManager
		if let sender = notificationManager?.userFromID(senderID) {
			return sender
		}
		logWarning("Can't find name of user \(senderID)")
		return UserInfo(id: senderID, name: "User_\(senderID)", 	surname: "???")
	}
}

extension SequenceType where Generator.Element: Notification {

	/// Returns the notifications presented by the UI.
	func userLevelNotifications() -> [Notification] {
		return self.latestNotificationsPerObject().chronologicalOrder().reverse()
	}
}
