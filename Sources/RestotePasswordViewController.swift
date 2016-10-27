//
//  RestotePasswordViewController.swift
//  GeoConfess
//
//  Created by Alex on March 18, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire

/// Controls the recover password screen.
final class RestotePasswordViewController: AppViewController {

    @IBOutlet weak private var emailField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
		resignFirstResponderWithOuterTouches(emailField)
    }

    @IBAction func confirmer(sender: UIButton) {
        if emailField.text!.isEmpty {
			showAlert(title: "Email", message: "L'adresse e-mail est vide")
        } else {
            resetPassword(emailField.text!)
        }
    }
    
	private func resetPassword(email: String) {
        let correctEmail = email.lowercaseString
        let params = ["user[email]": correctEmail]
        let URL = NSURL(string: "https://geoconfess.herokuapp.com/api/v1/passwords")
		showProgressHUD()
		
		// TODO: This operation really should be done by the `User` class!
        Alamofire.request(.POST, URL!, parameters: params).responseData {
			response in
			self.hideProgressHUD()
			guard let newResponse = response.response else {
				self.showAlert(
					title: "Email", message: "Pas de compte lié a l'adresse mail.")
				return
			}
			guard newResponse.statusCode == 201 else {
				self.showAlert(
					title: "Email", message: "Pas de compte lié a l'adresse mail.")
				return
			}
			self.showAlert(title: "Mot de Passe", message:
				"Un email vous a été envoyé pour réinitialiser votre mot de passe") {
				self.navigationController.popViewControllerAnimated(true)
			}
		}
	}
}
