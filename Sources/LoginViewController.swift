//
//  LoginViewController.swift
//  GeoConfess
//
//  Created by Donka on March 3, 2016.
//  Reviewed by Dan Dobrev on Abril 21, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the **Login** screen.
final class LoginViewController: AppViewController, UITextFieldDelegate {
    
	@IBOutlet private weak var emailField: AppTextField!
	@IBOutlet private weak var passwordField: AppTextField!
	@IBOutlet private weak var loginButton: UIButton!
    
	@IBOutlet private weak var emailTopSpace: NSLayoutConstraint!
	@IBOutlet private weak var signUpTopSpace: NSLayoutConstraint!
	@IBOutlet private weak var illustrationBottomSpace: NSLayoutConstraint!
	
	// MARK: - View Lifecyle
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		switch iPhoneModel {
		case .iPhone4:
			emailTopSpace.constant -= 55
			signUpTopSpace.constant -= 22
			illustrationBottomSpace.constant += 39
		case .iPhone5:
			emailTopSpace.constant -= 24
			signUpTopSpace.constant -= 16
		case .iPhone6, .iPhone6Plus, .futureModel:
			convertVerticalConstantFromiPhone6(emailTopSpace)
		}
		
		resignFirstResponderWithOuterTouches(emailField, passwordField)
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		let defaults = NSUserDefaults.standardUserDefaults()
		if let email = defaults.stringForKey(User.lastEmailKey) {
			emailField.text = email
		}
		checkNetworkReachabilityStatus()
	}
	
	private func checkNetworkReachabilityStatus() {
		if App.instance.isNetworkReachable {
			setLoginButton(enabled: true)
		} else {
			setLoginButton(enabled: false)
			showInternetOfflineAlert()
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
	}
	
	override func networkReachabilityStatusDidChange(status: NetworkReachabilityStatus) {
		checkNetworkReachabilityStatus()
	}
	
	// MARK: - Entering Login Information
    
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
		case emailField:
			passwordField.becomeFirstResponder()
		case passwordField:
			passwordField.resignFirstResponder()
			loginButtonTapped(loginButton)
		default:
			assertionFailure("Unexpected UITextField")
			break
		}
		return true
	}

	// MARK: - Performing Login

	private func setLoginButton(enabled enabled: Bool) {
		loginButton.enabled = enabled
		UIView.animateWithDuration(enabled ? 1.25 : 2.50) {
			let color = enabled ? UIButton.enabledColor : UIButton.disabledColor
			self.loginButton.backgroundColor = color
		}
	}
	
    @IBAction func loginButtonTapped(sender: UIButton) {
		let email = emailField.text ?? ""
		let password = passwordField.text ?? ""
		
        guard !email.isEmpty else {
			self.showAlert(title: "Email",
			               message: "Merci d'entrer votre adresse email.")
            return
        }
        guard User.isValidEmail(email) else {
            showAlert(title: "Email",
                      message: "Votre adresse email n’est pas valide!")
            return
        }
		guard User.isValidPassword(password) else {
            self.showAlert(title: "Mot de Passe",
                           message: "Le mot de passe doit faire plus de 6 caractères.")
            return
        }
		login(email: email, password: password)
    }

	private func login(email email: String, password: String) {
		setLoginButton(enabled: false)
		showProgressHUD()
		User.login(username: email, password: password) {
			result in
			self.hideProgressHUD()
			switch result {
			case .Success:
				self.performSegueWithIdentifier("openHomePage", sender: self)
			case .Failure:
				self.showAlert(
					title: "Échec de Connexion", message:
					"Email ou mot de passe invalide. S'il vous plaît réessayer.")
				self.setLoginButton(enabled: true)
			}
		}
	}
}
