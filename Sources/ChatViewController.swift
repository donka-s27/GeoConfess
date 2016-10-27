//
//  ChatViewController.swift
//  GeoConfess
//
//  Created  by Dan on May 5, 2016.
//  Reviewed by Dan Dobrev on June 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the chat UI.
/// See `ChatMessagesViewController` for the actual messaging view controller.
final class ChatViewController: AppViewControllerWithToolbar {
	
	@IBOutlet weak private var chatTitleLabel: UILabel!
	@IBOutlet weak private var chatView: UIView!
	private var chatViewController: ChatMessagesViewController!
	
	private var chattingWithUser: UserInfo!
	
	/// Set ups chatting with the specified user.
	/// This API handles all navigation edge cases internally.
	static func chatWithUser(otherUser: UserInfo, animated: Bool = true) {
		guard let navigationController = AppNavigationController.current else {
			preconditionFailure()
		}
		// Are we already chatting with this user?
		let topVC = navigationController.topViewController
		if let chatVC = topVC as? ChatViewController {
			if chatVC.chattingWithUser.id == otherUser.id {
				return
			}
		}
		// Create a new chatting session.
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let chatVC = storyboard.instantiateViewControllerWithIdentifier(
			"ChatViewController") as! ChatViewController
		chatVC.chattingWithUser = otherUser
		navigationController.pushViewController(chatVC, animated: animated)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		setChatTitle()
		
		assert(chatViewController == nil)
		chatViewController = storyboard!
			.instantiateViewControllerWithIdentifier("ChatMessagesViewController")
			as! ChatMessagesViewController
		addChildViewController(chatViewController)
		chatView.addSubview(chatViewController.view)
		chatViewController.didMoveToParentViewController(self)
		chatViewController.willChatWithUser(chattingWithUser)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		chatViewController.removeFromParentViewController()
		chatViewController = nil
	}
	
	private func setChatTitle() {
		precondition(chattingWithUser != nil)
		
		func font(name: String) -> [String: AnyObject] {
			return [NSFontAttributeName: UIFont(name: name, size: 19.0)!]
		}
		
		let lightFont = font("adventpro-Lt1")
		let prefix = NSAttributedString(
			string: "CONFESSEUR ", attributes: lightFont)
		
		let boldFont = font("adventpro-Bd3")
		let recipientName = NSAttributedString(
			string: chattingWithUser.name.uppercaseString, attributes: boldFont)
		
		let title = NSMutableAttributedString()
		title.appendAttributedString(prefix)
		title.appendAttributedString(recipientName)
		chatTitleLabel.attributedText = title
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		chatViewController?.view.frame = chatView.bounds
	}
	
	/// If we are coming from `NotificationsViewController` then we pop
	/// back two VCs, if available. This emulates the expected notification 
	/// button switching behaviour.
	override func notificatioButtonTapped(button: UIButton) {
		let vcStack = navigationController.viewControllers
		assert(vcStack.last === self)
		guard vcStack.count >= 3 else {
			super.notificatioButtonTapped(button)
			return
		}
		guard vcStack[vcStack.count - 2] is NotificationsViewController else {
			super.notificatioButtonTapped(button)
			return
		}
		let targetVC = vcStack[vcStack.count - 3]
		navigationController.popToViewController(targetVC, animated: true)
	}
}
