//
//  PriestSignUpViewController.swift
//  GeoConfess
//
//  Created  by whitesnow0827 on March 5, 2016.
//  Reviewed by Dan Dobrev on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the **Priest Sign Up** screen.
final class PriestSignUpViewController: AppViewController,
	UITextFieldDelegate, UIScrollViewDelegate {

	@IBOutlet private weak var scrollview: UIScrollView!
	@IBOutlet private weak var signUpButton: UIButton!
	
	@IBOutlet private weak var illustrationImage: UIImageView!
	@IBOutlet private weak var logoTopSpace: NSLayoutConstraint!

	/// Do any additional setup after loading the view.
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
			emailTextField, telephoneTextField
		)

		scrollview.contentSize.height = 1000
		scrollview.scrollEnabled = true
		scrollview.delegate = self
    }

    /// Do any additional setup before showing the view.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
		
		enableOrDisableSignUpButton()
        surnameTextField.becomeFirstResponder()
    }
    
	// MARK: - Entering Priest Information
	
	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var surnameTextField: UITextField!
	@IBOutlet private weak var emailTextField: UITextField!
	@IBOutlet private weak var telephoneTextField: UITextField!

	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
	               replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)
			
		switch textField {
		case nameTextField:
			priest.name = textAfterChange
		case surnameTextField:
			priest.surname = textAfterChange
		case emailTextField:
			priest.email = textAfterChange
		case telephoneTextField:
			priest.telephone = textAfterChange
		default:
			preconditionFailure("Unexpected UITextField")
		}
		enableOrDisableSignUpButton()
		return true
	}
	
	/// Called when 'return' key pressed. Return NO to ignore.
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
                priestSignUpButtonTapped(signUpButton)
            }
        default:
            preconditionFailure("unexpected UITextField")
        }
        return true
    }
	
	// MARK: - Signing Up Priest

	private let priest = PriestSignUp()

	private var shouldEnableSignUpButton: Bool {
		let errors = priest.detectErrors()
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
	
    @IBAction func priestSignUpButtonTapped(sender: UIButton) {
		precondition(shouldEnableSignUpButton)
		let errors = priest.detectErrors()

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
		self.performSegueWithIdentifier("enterPassword", sender: self)
    }
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		precondition(segue.identifier == "enterPassword")
        
        let passwordVC = segue.destinationViewController as! PriestPasswordViewController
        passwordVC.willEnterPasswordFor(priest)
	}
}
