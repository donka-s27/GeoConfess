//
//  UserPasswordViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on March 4, 2016.
//  Reviewed by Dan Dobrev on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the **User Password** screen.
final class UserPasswordViewController: AppViewController, UITextFieldDelegate {

	override func viewDidLoad() {
		super.viewDidLoad()
		resignFirstResponderWithOuterTouches(
			passwordTextField, passwordConfirmationTextField)
	}
	
	/// Do any additional setup before showing the view.
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		precondition(penitent != nil)

		penitent.password = ""
		penitent.confirmedPassword = ""
		penitent.nearbyPriestsNotification = false
		penitent.receiveNewsletter = false
		
		passwordTextField.text = nil
		passwordConfirmationTextField.text = nil
		notificationTick.on = false
		enableOrDisableSignUpButton()
		
		passwordTextField.becomeFirstResponder()
	}

	private var penitent: PenitentSignUp!
	
	func willEnterPasswordFor(penitent: PenitentSignUp) {
		self.penitent = penitent
	}

	// MARK: - Entering Penitent Passwords

	@IBOutlet weak private var passwordTextField: UITextField!
	@IBOutlet weak private var passwordConfirmationTextField: UITextField!
	@IBOutlet weak private var notificationTick: Tick!
	@IBOutlet weak private var signUpButton: UIButton!
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	               shouldChangeCharactersInRange range: NSRange,
				   replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)
		
		switch textField {
		case passwordTextField:
			penitent.password = textAfterChange
		case passwordConfirmationTextField:
			penitent.confirmedPassword = textAfterChange
		default:
			preconditionFailure("Unexpected UITextField")
		}
		enableOrDisableSignUpButton()
		return true
	}

	/// Called when *return key* pressed. Return false to ignore.
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
		case passwordTextField:
			passwordConfirmationTextField.becomeFirstResponder()
		case passwordConfirmationTextField:
			passwordConfirmationTextField.resignFirstResponder()
			if signUpButton.enabled {
				signUpButtonTapped(signUpButton)
			}
		default:
			preconditionFailure("Unexpected UITextField")
		}
		return true
	}
	
	@IBAction private func notificationTickChanged(sender: Tick) {
		penitent.nearbyPriestsNotification = sender.on
	}

	// MARK: - Signing Up Penitent

	private func enableOrDisableSignUpButton() {
		if shouldEnableSignUpButton {
			signUpButton.enabled = true
			signUpButton.backgroundColor = UIButton.enabledColor
		} else {
			signUpButton.enabled = false
			signUpButton.backgroundColor = UIButton.disabledColor
		}
	}

	private var shouldEnableSignUpButton: Bool {
		let errors = penitent.detectErrors()
		for error in errors {
			switch error {
			case .Malformed(let p) where p == .Password || p == .ConfirmedPassword:
				break
			case .Undefined:
				return false
			case .Malformed:
				return false
			}
		}
		return true
	}
	
	@IBAction func signUpButtonTapped(sender: UIButton) {
		precondition(shouldEnableSignUpButton)
		let errors = penitent.detectErrors()

		guard !errors.contains(.Malformed(.Password)) else {
			showAlert(
				title: "Mot de passe",
				message: "Le mot de passe doit faire plus de 6 caractères.") {
					self.passwordTextField.becomeFirstResponder()
			}
			return
		}
		guard !errors.contains(.Malformed(.ConfirmedPassword)) else {
			showAlert(
				title: "Confirmation mot de passe",
				message: "Les mots de passe doivent être identiques.") {
					self.passwordConfirmationTextField.becomeFirstResponder()
			}
			return
		}
		signUpUser()
	}
	
	private func signUpUser() {
		showProgressHUD()
		penitent.signUp(thenLogin: true) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success:
				self.performSegueWithIdentifier("enterApp", sender: self)
			case .Failure(let error):
				self.showAlertForError(error)
			}
		}
	}
}
