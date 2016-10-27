//
//  MeetRequestReplyViewController.swift
//  GeoConfess
//
//  Created by Donka on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation

final class MeetRequestReplyViewController: AppViewControllerWithToolbar {
	
	@IBOutlet weak private var penitentLabel: UILabel!
	
	@IBOutlet weak private var acceptButton: UIButton!
	@IBOutlet weak private var refuseButton: UIButton!
	
	private var meetRequest: MeetRequest!
	private var completion: (Bool -> Void)!
	
	/// Show view controller for replying to the specified penitent meet request.
	/// This API handles all navigation edge cases internally.
	static func replyToMeetRequest(meetRequest: MeetRequest,
	                               animated: Bool, completion: Bool -> Void) {
		guard let navigationController = AppNavigationController.current else {
			preconditionFailure()
		}
		// Create a new chatting session.
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let replyVC = storyboard.instantiateViewControllerWithIdentifier(
			"MeetRequestReplyViewController") as! MeetRequestReplyViewController
		replyVC.meetRequest = meetRequest
		replyVC.completion  = completion
		navigationController.pushViewController(replyVC, animated: animated)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		penitentLabel.text = meetRequest.penitent.name
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		completion?(false)
	}
	
	@IBAction func acceptButtonTapped(sender: UIButton) {
		assert(sender === acceptButton)
		meetRequest.accept {
			result in
			self.completion(true)
			self.completion = nil
			self.navigationController.popViewControllerAnimated(true)
		}
	}

	@IBAction func refuseButtonTapped(sender: UIButton) {
		assert(sender === refuseButton)
		meetRequest.refuse {
			result in
			self.completion(true)
			self.completion = nil
			self.navigationController.popViewControllerAnimated(true)
		}
	}
}
