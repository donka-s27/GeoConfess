//
//  ChoiceViewController.swift
//  GeoConfess
//
//  Created  by Dan on March 3, 2016.
//  Reviewed by Dan Dobrev on May 24, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the scene about choosing between **priest** or **user** sign up.
final class ChoiceViewController: AppViewController {

	@IBOutlet private weak var titleTopSpace: NSLayoutConstraint!
	@IBOutlet private weak var priestButtonTopSpace: NSLayoutConstraint!
	@IBOutlet private weak var illustrationBottomSpace: NSLayoutConstraint!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		switch iPhoneModel {
		case .iPhone4:
			convertVerticalConstantFromiPhone6(titleTopSpace)
			convertVerticalConstantFromiPhone6(priestButtonTopSpace)
			illustrationBottomSpace.constant += 39
		case .iPhone5, .iPhone6, .iPhone6Plus, .futureModel:
			convertVerticalConstantFromiPhone6(titleTopSpace)
			convertVerticalConstantFromiPhone6(priestButtonTopSpace)
		}
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		// Hack to skip 1 or more screens.
		/*
		pushUserSignUpViewController()
		pushUserPasswordViewController()
		*/
	}
	
	private func pushUserSignUpViewController() {
		performSegueWithIdentifier("signUpPenitent", sender: self)
	}

	private func pushUserPasswordViewController() {
		let passwordVC = storyboard!.instantiateViewControllerWithIdentifier(
			"UserPasswordViewController") as! UserPasswordViewController
		passwordVC.willEnterPasswordFor(PenitentSignUp())
		navigationController.pushViewController(passwordVC, animated: true)
	}
}
