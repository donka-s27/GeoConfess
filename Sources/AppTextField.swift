//
//  CustomTextField.swift
//  GeoConfess
//
//  Created by Donka on May 29, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// A customized `UITextField` control.
@IBDesignable
final class AppTextField: UITextField {

	override func awakeFromNib() {
		super.awakeFromNib()
		initTextField()
	}
	
	override func prepareForInterfaceBuilder() {
		super.prepareForInterfaceBuilder()
		initTextField()
	}

	private var initialized = false
	private var expectedHeight: CGFloat!

	private func initTextField() {
		assert(contentHorizontalAlignment == .Left)
		assert(contentVerticalAlignment   == .Center)
		assert(!initialized)
		
		// As a layout simplification, we expect each AppTextField
		// instance to contain a explicit *height* constraint.
		expectedHeight = nil
		for constraint in constraints where constraint.firstAttribute == .Height {
			assert(constraint.firstItem === self)
			assert(constraint.secondItem == nil)
			assert(constraint.multiplier == 1)
			assert(constraint.constant > 0)
			expectedHeight = constraint.constant
		}
		//assert(expectedHeight != nil)
		// TODO: Temporary hack.
		if expectedHeight == nil { expectedHeight = 32 }
		
		initIcon()
		initEditingColor()
		initialized = true
		
		addTarget(self, action: #selector(textFieldEditingDidBegin),
		          forControlEvents: .EditingDidBegin)
		addTarget(self, action: #selector(textFieldEditingDidEnd),
		          forControlEvents: .EditingDidEnd)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		#if TARGET_INTERFACE_BUILDER
			// This can only happens during IB updates only!
			if !initialized { return }
		#else
			assert(initialized)
			assert(bounds.height == expectedHeight)
		#endif
	}
	
	@objc private func textFieldEditingDidBegin() {
		setIconWhenEditingDidBegin()
		setEditingColorWhenEditingDidBegin()
	}
	
	@objc private func textFieldEditingDidEnd() {
		setIconWhenEditingDidEnd()
		setEditingColorWhenEditingDidEnd()
	}

	// MARK: - Drawing and Positioning Overrides
	
	private let horizontalPadding: CGFloat = 8
	private let verticalPadding: CGFloat = 5
	
	override func textRectForBounds(bounds: CGRect) -> CGRect {
		var rect = CGRect()
		rect.origin.x    = bounds.origin.x + iconHorizontalSpace + horizontalPadding
		rect.origin.y    = bounds.origin.y + verticalPadding
		rect.size.width  = bounds.width  - (iconHorizontalSpace + 2*horizontalPadding)
		rect.size.height = bounds.height - (2*verticalPadding)
		
		return rect
	}

	override func editingRectForBounds(bounds: CGRect) -> CGRect {
		return textRectForBounds(bounds)
	}
	
	/// Hack for correctly *centering* the `placeholder` text.
	/// Maybe this has something to do with our custom font (ie, *AdventPro Light*).
	override func placeholderRectForBounds(bounds: CGRect) -> CGRect {
		return textRectForBounds(bounds)
	}
	
	// MARK: - Background Color on Editing
	
	@IBInspectable
	var editingColor: Bool = false
	
	/// The background color used when the field is active.
	private let backgroundColorWhenEditing = UIColor(red: 237/255, green: 95/255,
	                                                 blue: 83/255, alpha: 0.5)
	private var backgroundColorWhenNotEditing: UIColor!
	
	private var textColorWhenEditing = UIColor.whiteColor()
	private var textColorWhenNotEditing: UIColor!
	
	private func initEditingColor() {
		guard editingColor else { return }
		textColorWhenNotEditing = textColor
		backgroundColorWhenNotEditing = backgroundColor
		setEditingColorWhenEditingDidEnd()
	}

	private func setEditingColorWhenEditingDidBegin() {
		textColor = textColorWhenEditing
		backgroundColor = backgroundColorWhenEditing
		setPlaceholderColor(UIColor.whiteColor())
	}

	private func setEditingColorWhenEditingDidEnd() {
		textColor = textColorWhenNotEditing
		backgroundColor = backgroundColorWhenNotEditing
		setPlaceholderColor(UIColor.lightGrayColor())
	}
	
	private func setPlaceholderColor(color: UIColor) {
		setValue(color, forKeyPath: "_placeholderLabel.textColor")
	}

	// MARK: - Icon on the Left Side
	
	@IBInspectable
	var icon: UIImage!

	@IBInspectable
	var editingIcon: UIImage!
	
	private var iconView: UIImageView!
	private var iconHorizontalSpace: CGFloat = 0
	private let iconLeftPadding: CGFloat = 6
	private let iconRightPadding: CGFloat = 6.5
	private let iconVerticalPadding: CGFloat = 6

	private func initIcon() {
		guard icon != nil && editingIcon != nil else { return }
		assert(icon.size == editingIcon.size)
		
		let iconHeight  = expectedHeight - 2*iconVerticalPadding
		let aspectRatio = icon.size.width / icon.size.height
		let iconWidth   = iconHeight * aspectRatio
		precondition(iconHeight > 0 && iconWidth > 0)
		
		iconHorizontalSpace = iconLeftPadding + iconWidth + iconRightPadding
		iconView = UIImageView()
		iconView.frame.size = CGSize(width: iconWidth, height: iconHeight)
		leftView = iconView
		leftViewMode = .Always
		setIconWhenEditingDidEnd()
	}
	
	override func leftViewRectForBounds(bounds: CGRect) -> CGRect {
		var rect = super.leftViewRectForBounds(bounds)
		rect.origin.x += iconLeftPadding
		return rect
	}
	
	private func setIconWhenEditingDidBegin() {
		guard iconView != nil else { return }
		iconView.image = editingIcon
	}

	private func setIconWhenEditingDidEnd() {
		guard iconView != nil else { return }
		iconView.image = icon
	}

	// MARK: - Horizontal Line

	@IBInspectable
	var horizontalLine: Bool = false
	
	override func drawRect(rect: CGRect) {
		super.drawRect(rect)
		
		guard horizontalLine && !editing else { return }
		let size = bounds.size
		let bottomLeft  = CGPoint(x: 0, y: size.height)
		let bottomRight = CGPoint(x: size.width, y: size.height)
		let horizontalLinePath = UIBezierPath()
		horizontalLinePath.moveToPoint(bottomLeft)
		horizontalLinePath.addLineToPoint(bottomRight)
		
		UIColor.lightGrayColor().setStroke()
		horizontalLinePath.stroke()
	}
}
