//
//  UserSignUp.swift
//  GeoConfess
//
//  Created by Donka on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// MARK: - UserSignUp Class

/// Common sign up information for *petinents* and *priests*.
class UserSignUp {
	
	var name: String = ""
	var surname: String = ""
	var email: String = ""
	var telephone: String = ""

	var password: String = ""
	var confirmedPassword: String = ""
	var nearbyPriestsNotification: Bool!
	var receiveNewsletter: Bool!
	
	private let role: User.Role
	
	init(role: User.Role) {
		self.role = role
	}
	
	func signUp(thenLogin doLogin: Bool, completion: (Result<Void, Error>) -> Void) {
		precondition(detectErrors().isEmpty)
		
		// This API endpoint is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/registrations/create.html
		let signUpURL = NSURL(string: "\(App.serverAPI)/registrations")
		let request = Alamofire.request(.POST, signUpURL!, parameters: paramsForSignUp())
		request.validate().responseJSON {
			response in
			switch response.result {
			case .Success(let data):
				let json = JSON(data).dictionary!
				guard json["result"]?.string == "success" else {
					let status = json["status"]!.string!
					let error  = json["error"]!.string!
					log("Sign up FAILED: \(status), \(error)\n")
					completion(.Failure(Error(code: .unexpectedServerError)))
					return
				}
				if doLogin {
					self.loginUser(completion)
				} else {
					completion(.Success())
				}
			case .Failure(let error):
				logError("Sign up FAILED:\n\(error.readableDescription)")
				completion(.Failure(Error(causedBy: error)))
			}
		}
	}
	
	private func loginUser(completion: (Result<Void, Error>) -> Void) {
		User.login(username: email, password: password) {
			result in
			switch result {
			case .Success:
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	private func paramsForSignUp() -> [String: AnyObject] {
		let user = [
			"role"         : role.rawValue,
			"email"        : email,
			"password"     : password,
			"name"         : name,
			"surname"      : surname,
			"phone"        : telephone,
			"newsletter"   : "\(receiveNewsletter!)"
			/*
			Antoine: 
			@oleg please set every new user’s notification attribute automatically 
			to true (default: true) for the time being. 
			@paulo you can remove the check box upon user’s creation and the 
			corresponding parameter sent to API. That will fix it for now.
			
			We don't need that feature for now anyways.
			*/
			//"notification" : "\(nearbyPriestsNotification!)",
		]
		return ["user" : user]
	}
	
	// MARK: Detecting Errors
	
	enum SignUpError: Equatable, CustomStringConvertible {
		case Undefined(Property)
		case Malformed(Property)
		
		var description: String {
			switch self {
			case .Undefined(let property):
				return "Undefined(\(property))"
			case .Malformed(let property):
				return "Malformed(\(property))"
			}
		}
	}

	enum Property: String, CustomStringConvertible {
		case Name, Surname, Email, Telephone
		case Password, ConfirmedPassword
		case NearbyPriestsNotification, ReceiveNewsletter
		case CelebretURL
		
		var description: String {
			return self.rawValue
		}
	}
	
	func detectErrors() -> [SignUpError] {
		var errors = [SignUpError]()
		func error(err: SignUpError) { errors.append(err) }
		
		// Undefined errors.
		// Note: telephone property is optional.
		if name.isEmpty {
			error(.Undefined(.Name))
		}
		if surname.isEmpty {
			error(.Undefined(.Surname))
		}
		if email.isEmpty {
			error(.Undefined(.Email))
		}
		if password.isEmpty {
			error(.Undefined(.Password))
		}
		if confirmedPassword.isEmpty {
			error(.Undefined(.ConfirmedPassword))
		}
		if nearbyPriestsNotification == nil {
			error(.Undefined(.NearbyPriestsNotification))
		}
		if receiveNewsletter == nil {
			error(.Undefined(.ReceiveNewsletter))
		}

		// Malformed errors.
		if !User.isValidEmail(email) {
			error(.Malformed(.Email))
		}
		if !telephone.isEmpty && !User.isValidEmail(email) {
			error(.Malformed(.Telephone))
		}
		if !User.isValidPassword(password) {
			error(.Malformed(.Password))
		}
		if confirmedPassword != password {
			error(.Malformed(.ConfirmedPassword))
		}
		
		return errors
	}
}

func ==(left: UserSignUp.SignUpError, right: UserSignUp.SignUpError) -> Bool {
	switch (left, right) {
	case (.Undefined(let pa), .Undefined(let pb)):
		return pa == pb
	case (.Malformed(let pa), .Malformed(let pb)):
		return pa == pb
	default:
		return false
	}
}

// MARK: - PenitentSignUp Class

/// Penitent sign up information.
final class PenitentSignUp: UserSignUp {

	init() {
		super.init(role: .Penitent)
	}
}

// MARK: - PriestSignUp Class

/// Priest sign up information.
final class PriestSignUp: UserSignUp {
	
	var celebretURL: NSURL! = nil

	init() {
		super.init(role: .Priest)
	}
	
	private override func paramsForSignUp() -> [String : AnyObject] {
		guard let celebretURL = celebretURL else { preconditionFailure() }
		
		var params = super.paramsForSignUp()
		var user = params["user"] as! [String : String]
		user["celebret_url"] = String(celebretURL)
		params["user"] = user
		return params
	}
	
	override func detectErrors() -> [SignUpError] {
		var errors = [SignUpError]()
		if celebretURL == nil {
			errors.append((.Undefined(.CelebretURL)))
		}
		return super.detectErrors() + errors
	}
}
