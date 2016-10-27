//
//  LoadingViewController.swift
//  GeoConfess
//
//  Created  by Dan on February 2, 2016.
//  Reviewed by Dan Dobrev on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the **loading** screen.
final class LoadingViewController: UIViewController {

    @IBOutlet weak private var loadingProgress: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		loadingProgress.hidden = false
		loadingProgress.hidesWhenStopped = true
		loadingProgress.startAnimating()
		Timer.scheduledTimerWithTimeInterval(1.0) {
			self.waitAppInitialization()
		}
	}
	
	private func waitAppInitialization(waitAttempt: Int = 0) {
		let app = App.instance
		if app.isInitialized {
			loginUserOrPresentLoginViewController()
			return
		}
		showInternetOfflineAlert {
			if app.isInitialized {
				self.loginUserOrPresentLoginViewController()
				return
			}
			let waitTime = (Double(waitAttempt) + 1) * 7
			Timer.scheduledTimerWithTimeInterval(waitTime) {
				self.waitAppInitialization(waitAttempt + 1)
			}
		}
	}
	
	private func loginUserOrPresentLoginViewController() {
		// Logins the last successfully logged in user.
		let defaults = NSUserDefaults.standardUserDefaults()
		guard let email = defaults.stringForKey(User.lastEmailKey) else {
			presentLoginViewController()
			return
		}
		guard let password = defaults.stringForKey(User.lastPasswordKey) else {
			presentLoginViewController()
			return
		}
		User.login(username: email, password: password) {
			result in
			self.loadingProgress.stopAnimating()
			switch result {
			case .Failure:
				self.performSegueWithIdentifier("login", sender: self)
			case .Success:
				self.performSegueWithIdentifier("autoLogin", sender: self)
			}
		}
	}
	
	private func presentLoginViewController() {
		Timer.scheduledTimerWithTimeInterval(3.5) {
			self.loadingProgress.stopAnimating()
			self.performSegueWithIdentifier("login", sender: self)
		}
	}
}
