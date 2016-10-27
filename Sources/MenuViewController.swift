//
//  MenuViewController.swift
//  GeoConfess
//
//  Created by Donka on April 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import SideMenu

/// Controls the side menu available at `MainViewController`.
final class MenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet private var testView: UIView!
	@IBOutlet private var bottomImage: UIImageView!
	@IBOutlet weak var versionLabel: UILabel!
	@IBOutlet private weak var bottomImageWidth: NSLayoutConstraint!
	@IBOutlet private weak var bottomImageHeight: NSLayoutConstraint!
	
	private let itemHeight = CGFloat(45)
	
	private var homePageController: HomePageViewController!

	private static let storyboard = UIStoryboard(name: "Menu", bundle: nil)
	
	static func createFor(homePageController homePageController: HomePageViewController)
		-> UISideMenuNavigationController {
		let menuNavController = storyboard.instantiateInitialViewController()
			as! UISideMenuNavigationController
		assert(menuNavController.leftSide)
		
		let menuController = menuNavController.viewControllers[0] as! MenuViewController
		menuController.homePageController = homePageController
			
		SideMenuManager.menuPresentMode = .MenuSlideIn
		SideMenuManager.menuAnimationFadeStrength = 0.45
		SideMenuManager.menuFadeStatusBar = false
		SideMenuManager.menuAnimationPresentDuration = 0.35
		SideMenuManager.menuAnimationDismissDuration = 0.20
		SideMenuManager.menuWidth = UIScreen.mainScreen().bounds.width * 0.70
		SideMenuManager.menuLeftNavigationController = menuNavController

		return menuNavController
	}
    
	// MARK: - View Controller Lifecycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationController!.navigationBarHidden = true
		if UIScreen.mainScreen().bounds.width > 320 {
			tableView.scrollEnabled = false
		}
		
		let config: String
		#if DEBUG
			config = "(debug)"
		#elseif RELEASE
			config = ""
		#else
			config = "(???)"
		#endif
		let app = App.instance
		versionLabel.text = "\(app.version) build \(app.buildNumber) \(config)"
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .Slide)
		
		setMenuTitle()
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Slide)
	}
	
	// MARK: - TableView Data Source
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView,
	                        numberOfRowsInSection section: Int) -> Int {
		assert(section == 0)
		return MenuItem.members.count
	}
	
	func tableView(tableView: UITableView,
		cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		
		let item = MenuItem(rowIndex: indexPath.row)!
		let itemCell = tableView.dequeueReusableCellWithIdentifier(
			item.cellIdentifier, forIndexPath: indexPath) as! MenuItemCell
		
		itemCell.itemName.text = item.localizedName
		itemCell.itemName.preferredMaxLayoutWidth = SideMenuManager.menuWidth * 0.85
		itemCell.itemName.sizeToFit()
		return itemCell
	}

	// MARK: - TableView Delegate

	func tableView(tableView: UITableView,
	                        heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return itemHeight
	}
	
	func tableView(tableView: UITableView,
	                        didSelectRowAtIndexPath indexPath: NSIndexPath) {
		homePageController.dismissViewControllerAnimated(true, completion: nil)
		func performSegueWithIdentifier(id: String, keepMenu: Bool) {
			HomePageViewController.openMenuOnNextPresentation = keepMenu
			homePageController.performSegueWithIdentifier(id, sender: self)
		}
		
		switch MenuItem(rowIndex: indexPath.row)! {
		case .ConfessionFAQ:
			performSegueWithIdentifier("readConfessionFAQ", keepMenu: true)
		case .WhyConfess:
			performSegueWithIdentifier("readWhyConfess", keepMenu: true)
		case .ConfessionNotes:
			performSegueWithIdentifier("readConfessionPreparation", keepMenu: true)
		case .Share:
			performSegueWithIdentifier("browseContacts", keepMenu: true)
		case .Settings:
			performSegueWithIdentifier("editProfile", keepMenu: true)
		//case .Help:
		//	performSegueWithIdentifier("readHelp", keepMenu: true)
		case .MakeDonation:
			let app = UIApplication.sharedApplication()
			app.openURL(NSURL(string: "https://donner.ktotv.com/a/mon-don")!)
		case .Logout:
			User.current.logoutInBackground {
				result in
                switch result {
                case .Success:
                    performSegueWithIdentifier("login", keepMenu: false)
                case .Failure(let error):
					self.showAlertForError(error)
                }
			}
		}
    }

	// MARK: - Menu Title

	@IBOutlet private var menuTitle: UIView!
	@IBOutlet private weak var menuTitleHeight: NSLayoutConstraint!
	
	@IBOutlet private weak var userNameLabel: UILabel!
	@IBOutlet private weak var userSurNameLabel: UILabel!
	
	private func setMenuTitle() {
		let user = User.current!
		userNameLabel.text = user.name
		userSurNameLabel.text = user.surname
	}
}
