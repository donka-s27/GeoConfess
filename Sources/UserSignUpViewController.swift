//
//  UserSignUpViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on March 4, 2016.
//  Reviewed by Dan Dobrev on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the **User Sign Up** screen.
final class UserSignUpViewController: AppViewController, UITextFieldDelegate {

	@IBOutlet private weak var signUpButton: UIButton!
	
	@IBOutlet private weak var illustrationImage: UIImageView!
	@IBOutlet private weak var logoTopSpace: NSLayoutConstraint!
	
    override func viewDidLoad() {
		super.viewDidLoad()
		
		switch iPhoneModel {
		case .iPhone4:
			logoTopSpace.constant -= 12
			illustrationImage.hidden = true
		case .iPhone5:
			logoTopSpace.constant -= 16
		case .iPhone6, .iPhone6Plus, .futureModel:
			break
		}
		
		resignFirstResponderWithOuterTouches(
			nameTextField, surnameTextField,
			emailTextField, telephoneTextField)
    }
    
	/// Do any additional setup before showing the view.
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		surnameTextField.becomeFirstResponder()
	}
	
	// MARK: - Entering Penitent Information

	@IBOutlet weak private var surnameTextField:   UITextField!
	@IBOutlet weak private var nameTextField:      UITextField!
	@IBOutlet weak private var emailTextField:     UITextField!
	@IBOutlet weak private var telephoneTextField: UITextField!
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	               shouldChangeCharactersInRange range: NSRange,
				   replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)

		switch textField {
		case surnameTextField:
			penitent.surname = textAfterChange
		case nameTextField:
			penitent.name = textAfterChange
		case emailTextField:
			penitent.email = textAfterChange
		case telephoneTextField:
			penitent.telephone = textAfterChange
		default:
			preconditionFailure("unexpected UITextField")
		}
		enableOrDisableSignUpButton()
		return true
	}

	/// Called when *return key* pressed. Return false to ignore.
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
		case surnameTextField:
			nameTextField.becomeFirstResponder()
		case nameTextField:
			emailTextField.becomeFirstResponder()
		case emailTextField:
			telephoneTextField.becomeFirstResponder()
		case telephoneTextField:
			telephoneTextField.resignFirstResponder()
			if signUpButton.enabled {
				signUpButtonTapped(signUpButton)
			}
		default:
			preconditionFailure("unexpected UITextField")
		}
		return true
	}
	
	// MARK: - Signing Up Penitent
	
	private let penitent = PenitentSignUp()

	private var shouldEnableSignUpButton: Bool {
		let errors = penitent.detectErrors()
		for error in errors {
			switch error {
			case .Undefined(let p) where p == .Name || p == .Surname || p == .Email:
				return false
			case .Undefined:
				break
			case .Malformed:
				break
			}
		}
		return true
	}
	
	private func enableOrDisableSignUpButton() {
		if shouldEnableSignUpButton {
			signUpButton.enabled = true
			signUpButton.backgroundColor = UIButton.enabledColor
		} else {
			signUpButton.enabled = false
			signUpButton.backgroundColor = UIButton.disabledColor
		}
	}
	
	@IBAction func signUpButtonTapped(button: UIButton) {
		precondition(shouldEnableSignUpButton)
		let errors = penitent.detectErrors()
		
		guard !errors.contains(.Malformed(.Email)) else {
			showAlert(title: "Adresse mail",
			          message: "Votre adresse email n’est pas valide!") {
						self.emailTextField.becomeFirstResponder()
			}
			return
		}
		guard !errors.contains(.Malformed(.Telephone)) else {
				showAlert(title: "Téléphone",
				          message: "Numéro de téléphone invalide!") {
							self.telephoneTextField.becomeFirstResponder()
				}
				return
		}
		performSegueWithIdentifier("enterPassword", sender: self)
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		precondition(segue.identifier == "enterPassword")
		
		let passwordVC = segue.destinationViewController as! UserPasswordViewController
		passwordVC.willEnterPasswordFor(penitent)
	}
}

