//
//  InactiveUserViewController.swift
//  GeoConfess
//
//  Created by Viktor Pavlov on May 31, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import SideMenu

/// A very simple view controller which *blurs* the screen.
final class InactiveUserViewController: UIViewController {
	
	static func presentViewControllerOverCurrent(current: UIViewController) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let viewController = storyboard
			.instantiateViewControllerWithIdentifier("InactiveUserViewController")
			as! InactiveUserViewController
		viewController.modalPresentationStyle = .OverCurrentContext
		current.presentViewController(viewController, animated: true, completion: nil)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
    @IBAction private func logOutButtonTapped(sender: AnyObject) {
        User.current.logoutInBackground {
            result in
            switch result {
            case .Success:
                self.performSegueWithIdentifier("login", sender: self)
            case .Failure(let error):
				self.showAlertForError(error)
            }
        }
    }
}