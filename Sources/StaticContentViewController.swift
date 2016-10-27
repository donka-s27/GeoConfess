//
//  StaticContentViewController.swift
//  GeoConfess
//
//  Created by Donka on June 3, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import WebKit

/// Presents static content from HTML file.
final class StaticContentViewController: AppViewControllerWithToolbar {
	
	@IBOutlet weak private var titleLabel: UILabel!
	@IBOutlet weak private var mainView: UIView!
	private var webView: WKWebView!
	
	private var htmlURL: NSURL!
	private var htmlTitle: String!
	
	func loadContent(title title: String, html: String) {
		let mainBundle = NSBundle.mainBundle()
		self.htmlTitle = title
		self.htmlURL = mainBundle.URLForResource(
			"Static Content/\(html)", withExtension: "html")!
	}
	
	func loadContent(title title: String, url: NSURL) {
		self.htmlTitle = title
		self.htmlURL = url
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		setUpWebView()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		titleLabel.text = htmlTitle
		webView.loadRequest(NSURLRequest(URL: htmlURL))
	}
	
	private func setUpWebView() {
		webView = WKWebView()
		webView.translatesAutoresizingMaskIntoConstraints = false
		let constraints: [NSLayoutConstraint] = [
			// height and width
			equalsConstraint(
				item:   webView,  attribute: .Height,
				toItem: mainView, attribute: .Height),
			equalsConstraint(
				item:   webView,  attribute: .Width,
				toItem: mainView, attribute: .Width),
			// top and right
			equalsConstraint(
				item:   webView,  attribute: .Top,
				toItem: mainView, attribute: .Top),
			equalsConstraint(
				item:   webView,  attribute: .Trailing,
				toItem: mainView, attribute: .Trailing)
		]
		mainView.addSubview(webView)
		mainView.addConstraints(constraints)
	}
}
