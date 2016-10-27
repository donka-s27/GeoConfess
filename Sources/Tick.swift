/*
The MIT License (MIT)

Copyright (c) 2014-2016 Dan, Antoine Berton

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall
be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

//
//  TickButton.swift
//  GeoConfess
//
//  Created by Donka on May 26, 2016.
//

import UIKit

/// A simple, custom tick toogle (ie, check mark) .
@IBDesignable
final class Tick: UIControl {

	override func awakeFromNib() {
		super.awakeFromNib()
		setUpView()
	}
	
	override func prepareForInterfaceBuilder() {
		super.prepareForInterfaceBuilder()
		setUpView()
	}
	
	@IBInspectable
	var offImage: UIImage!
	
	@IBInspectable
	var onImage: UIImage!
	
	private var offImageView: UIImageView!
	private var onImageView: UIImageView!
	
	private var initialized = false
	
	private func setUpView() {
		assert(!initialized)
		assert(offImage != nil && onImage != nil)
		offImageView = UIImageView(image: offImage)
		onImageView  = UIImageView(image: onImage)
		addSubview(offImageView)
		addSubview(onImageView)
		initialized = true
		setOn(on, animated: false)
	}
	
	// MARK: - Setting the Off/On State

	private var _on: Bool = false
		
	@IBInspectable
	var on: Bool {
		get { return _on }
		set { setOn(newValue, animated: false) }
	}
	
	func setOn(on: Bool, animated: Bool) {
		_on = on
		guard initialized else { return }
		setNeedsDisplay()
		
		if !animated {
			onImageView.alpha = on ? 1 : 0
			return
		}
		onImageView.alpha = on ? 0 : 1
		UIView.animateWithDuration(
			on ? 0.35 : 0.20,
			animations: {
				self.onImageView.alpha = on ? 1 : 0
			},
			completion: {
				animationFinished in
				/* empty */
			}
		)
	}
	
	// MARK: - Animation and Layout

	/// Lays out subviews.
	override func layoutSubviews() {
		super.layoutSubviews()
		
		#if TARGET_INTERFACE_BUILDER
			// This can only happens during IB updates only!
			if !initialized { return }
		#else
			assert(initialized)
		#endif
		assert(onImage.size == offImage.size)
		assert(abs(bounds.size.aspectRatio - onImage.size.aspectRatio) <= 0.01)
		
		// Set frame to 100% of superview.
		onImageView.frame  = bounds
		offImageView.frame = bounds
	}

	override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
		super.touchesEnded(touches, withEvent: event)
		if userInteractionEnabled {
			setOn(!on, animated: true)
			sendActionsForControlEvents(.ValueChanged)
		}
	}
}
