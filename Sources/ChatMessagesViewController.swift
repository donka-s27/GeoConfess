//
//  ChatMessagesViewController.swift
//  GeoConfess
//
//  Created  by Dan Markov on May 5, 2016.
//  Reviewed by Donka Simeonov on June 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import JSQMessagesViewController

/// Controls the main chat view.
///
/// This is a *embedded* view controller, so events
/// `viewWillAppear` and `viewWillDisappear` will *not* be fired.
final class ChatMessagesViewController: JSQMessagesViewController,
JSQMessagesComposerTextViewPasteDelegate, NotificationObserver,
UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	private var localUser: User!
	private var remoteUser: UserInfo!
	
	func willChatWithUser(recipient: UserInfo) {
		precondition(view != nil)
		
		localUser  = User.current!
		remoteUser = recipient

		// Required for JSQMessagesCollectionViewDataSource protocol.
		senderId = "\(localUser.id)"
		senderDisplayName = localUser.name
		
		localUser.notificationManager.addObserver(self)
		reloadMessages()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = UIColor.clearColor()
		showTypingIndicator = false
		automaticallyScrollsToMostRecentMessage = true
		collectionView.typingIndicatorDisplaysOnLeft = true
		collectionView.backgroundColor = UIColor.clearColor()
		
		let margin = CGSize(width: 9, height: 0)
		collectionView.collectionViewLayout.outgoingAvatarViewSize = margin
		collectionView.collectionViewLayout.incomingAvatarViewSize = margin
		
		let toolbar = inputToolbar.contentView
		toolbar.leftBarButtonItem = nil
		toolbar.rightBarButtonItem.setTitle("Envoyer", forState: .Normal)
		toolbar.rightBarButtonItem.setTitle("Envoyer", forState: .Highlighted)
		toolbar.rightBarButtonItemWidth = 64
		toolbar.textView.placeHolder = "Nouveau Message"
	}

	override func didMoveToParentViewController(parent: UIViewController?) {
		super.didMoveToParentViewController(parent)
		// Closing view controller?
		if parent == nil {
			localUser.notificationManager.removeObserver(self)
		}
	}
	
    // MARK: - Messages Data Model
	
	/// This is the UI level messages model.
	private var messages = [JSQMessage]()

	func notificationManager(manager: NotificationManager,
	                         didAddMessages newMessages: [Message]) {
		
		assert(collectionView.numberOfSections() == 1)
		var insertedMessages = [JSQMessage]()
		var insertedMessagesIndexes = [NSIndexPath]()
		for message in newMessages where message.senderID == self.remoteUser.id {
			precondition(message.recipientID == self.localUser.id)
			let index = messages.count + insertedMessages.count
			insertedMessages.append(JSQMessage(fromSenderOf: message))
			insertedMessagesIndexes.append(NSIndexPath(forItem: index, inSection: 0))
		}
		guard insertedMessages.count > 0 else { return }
		
		showTypingIndicator = true
		scrollToBottomAnimated(true)
		performBatchUpdates(delay: 1.25) {
			self.messages.appendContentsOf(insertedMessages)
			self.collectionView.insertItemsAtIndexPaths(	insertedMessagesIndexes)
			self.finishReceivingMessageAnimated(true)
		}
	}
	
	private func performBatchUpdates(delay delay: NSTimeInterval, updates: () -> Void) {
		runAfterDelay(delay) {
			self.collectionView.performBatchUpdates(updates, completion: nil)
		}
	}

	func notificationManager(manager: NotificationManager,
	                         didAddNotifications notifications: [Notification]) {
		/* empty */
	}
	
	func notificationManager(manager: NotificationManager,
	                         didDeleteNotifications notifications: [Notification]) {
		// This might be a data model fresh, so is better to reload all messages.
		reloadMessages()
	}
	
	func notificationManager(manager: NotificationManager,
	                         didReceivePushNotification notification: Notification) {
		/* empty */
	}

	func notificationManager(manager: NotificationManager, didReceivePushNotification
							 notification: PriestAvailabilityNotification) {
		/* empty */
	}

	private func reloadMessages() {
		messages.removeAll()
		for message in localUser.notificationManager.messages {
			if message.senderID == localUser.id && message.recipientID == remoteUser.id {
				messages.append(JSQMessage(fromSenderOf: message))
			}
			if message.senderID == remoteUser.id && message.recipientID == localUser.id {
				messages.append(JSQMessage(fromSenderOf: message))
			}
		}
		collectionView.reloadData()
	}

    override func collectionView(
		collectionView: UICollectionView,
		numberOfItemsInSection section: Int) -> Int {
		return messages.count
    }
    
	override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
		return messages[indexPath.item]
	}
	
    override func collectionView(
		collectionView: UICollectionView,
		cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(
			collectionView, cellForItemAtIndexPath: indexPath)
			as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        if message.senderID == localUser.id {
            cell.textView.textColor = UIColor.whiteColor()
        } else {
            cell.textView.textColor = UIColor.blackColor()
        }
        return cell
    }
	
    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        messages.removeAtIndex(indexPath.item)
    }

	private let bubbleFactory = JSQMessagesBubbleImageFactory()

    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!)
		-> JSQMessageBubbleImageDataSource! {

		switch messages[indexPath.item].senderID {
		case localUser.id:
			let outgoingColor = UIColor(
				red: 237/255, green: 95/255, blue: 103/255, alpha: 1)
			return bubbleFactory.outgoingMessagesBubbleImageWithColor(outgoingColor)
		case remoteUser.id:
			let incomingColor = UIColor(white: 0.81, alpha: 1.0)
			return bubbleFactory.incomingMessagesBubbleImageWithColor(incomingColor)
		default:
			preconditionFailure("Unexpected sender ID.")
		}
		
		/*
        if message.senderID == localUser.id {
			//
        } else {
			//UIColor.lightGrayColor())
        }
		*/
    }
    
    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!)
		-> JSQMessageAvatarImageDataSource! {
        /**
         *  Return your previously created avatar image data objects.
         *
         *  Note: these the avatars will be sized according to these values:
         *
         *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
         *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
         *
         *  Override the defaults in `viewDidLoad`
         */
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 didTapCellAtIndexPath indexPath: NSIndexPath!,
								 touchLocation: CGPoint) {
        print("TODO: Need to do some translation heaya!")
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 header headerView: JSQMessagesLoadEarlierHeaderView!,
								 didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("TODO: need to load earlier messages")
    }
	
	// MARK: - Sending Text Messages
	
	override func didPressSendButton(button: UIButton!, withMessageText text: String!,
	                                 senderId: String!, senderDisplayName: String!,
	                                 date: NSDate!) {
		/**
		*  Sending a message. Your implementation of
		*  this method should do *at least* the following:
		*
		*  1. Play sound (optional)
		*  2. Add new id<JSQMessageData> object to your data source
		*  3. Call `finishSendingMessage`
		*/
		sendTextMessage(text, fromMe: true, date: date!, playSound: true)
	}
	
	private func sendTextMessage(text: String, fromMe: Bool,
	                             date: NSDate, playSound: Bool) {
		localUser.notificationManager.sendMessageTo(remoteUser.id, text: text) {
			result in
			switch result {
			case .Success:
				break
			case .Failure(let error):
				logError("sendTextMessage failed: \(error)")
			}
		}
		let userID   = fromMe ? localUser.id   : remoteUser.id
		let userName = fromMe ? localUser.name : remoteUser.name
		let message = JSQMessage(senderID: userID, senderName: userName,
		                         date: date, text: text)
		messages.append(message)
		
		if playSound {
			JSQSystemSoundPlayer.jsq_playMessageSentSound()
		}
		finishSendingMessageAnimated(true)
		receiveFakeReply()
	}
	
	func composerTextView(textView: JSQMessagesComposerTextView!,
	                      shouldPasteWithSender sender: AnyObject!) -> Bool {
		guard let image = UIPasteboard.generalPasteboard().image else { return true }
		
		let imageMedia = JSQPhotoMediaItem(image: image)
		let message = JSQMessage(senderID: localUser.id, senderName: localUser.name,
		                         date: NSDate(), media: imageMedia)
		messages.append(message)
		finishSendingMessage()
		return false
	}
	
	// MARK: - Messages Refresh
	
	private var refreshControl: UIRefreshControl!
	
	private func addRefreshControl() {
		refreshControl = UIRefreshControl()
		refreshControl.attributedTitle =
			NSAttributedString(string: "Chargement des messages récents...")
		refreshControl.addTarget(
			self, action: #selector(self.loadEarlierMessages),
			forControlEvents: UIControlEvents.ValueChanged)
		collectionView.addSubview(refreshControl!)
	}
	
	@objc private func loadEarlierMessages() {
		refreshControl!.endRefreshing()
	}
	
	// MARK: - Testing Mode
	
	private func receiveFakeReply() {
		guard chatBotEnabled else { return }
		showTypingIndicator = true
		scrollToBottomAnimated(true)
		runAfterDelay(1.5) {
			JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
			let newMessage = JSQMessage(
				senderID:	self.remoteUser.id,
				senderName:	self.remoteUser.name,
				date:		NSDate(),
				text: 		"I am here")
			self.messages.append(newMessage)
			self.finishReceivingMessageAnimated(true)
		}
	}
	
	private var chatBotEnabled: Bool {
		let key = "Simple Chat Bot Enabled"
		let enabled = (App.instance.properties[key]! as! NSNumber).boolValue
		return enabled
	}
}

// MARK: - JSQMessage Extensions

extension JSQMessage {
	
	convenience init(senderID: ResourceID, senderName: String,
	                 date: NSDate, text: String) {
		self.init(senderId: String(senderID), senderDisplayName: senderName,
		          date: date, text: text)
	}

	convenience init(senderID: ResourceID, senderName: String,
	                 date: NSDate, media: JSQMessageMediaData) {
		self.init(senderId: String(senderID), senderDisplayName: senderName,
		          date: date, media: media)
	}

	convenience init(fromSenderOf message: Message) {
		let senderId = message.senderID
		let name = "User_\(message.senderID)"
		self.init(senderID: senderId, senderName: name,
		          date: message.createdAt, text: message.text)
	}

	convenience init(fromRecipientOf message: Message) {
		let senderId = message.recipientID
		let name = "User_\(message.recipientID)"
		self.init(senderID: senderId, senderName: name,
		          date: message.createdAt, text: message.text)
	}
	
	var senderID: ResourceID {
		return ResourceID(senderId)!
	}
}
