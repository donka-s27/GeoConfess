//
//  MenuItemCell.swift
//  GeoConfess
//
//  Created by Donka on 05/04/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import UIKit
import SideMenu

/// A cell in the table controlled by `LeftMenuViewController`.
final class MenuItemCell: UITableViewVibrantCell {

	@IBOutlet weak var itemName: UILabel!
	@IBOutlet weak var arrow: UIImageView!
	
	/// Initialization code.
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	/// Configure the view for the selected state.
	override func setSelected(selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
	}
}

/// Menu item identifier.
enum MenuItem: UInt {
	
	case ConfessionFAQ   = 0
	case WhyConfess      = 1
	case ConfessionNotes = 2
	case Share           = 3
	case Settings        = 4
	//case Help            = 5
    case MakeDonation    = 5
	case Logout          = 6
	
	static let members = [
		ConfessionFAQ, WhyConfess, ConfessionNotes,
		Share, Settings, MakeDonation, Logout
	]
	
	init!(rowIndex rawValue: Int) {
		self.init(rawValue: UInt(rawValue))
	}
	
	var rowIndex: Int {
		return Int(rawValue)
	}
	
	var cellIdentifier: String {
		return "MenuItemCell"
	}
	
	var localizedName: String {
		switch self {
		case .ConfessionFAQ:
			return "Qu’est-ce que la confession"
		case .WhyConfess:
			return "Pourquoi se confesser"
		case .ConfessionNotes:
			return "Préparer sa confession"
		case .Share:
			return "Partager"
		case .Settings:
			return "Modifications du compte"
		//case .Help:
		//	return "Aide"
		case .MakeDonation:
			return "Faire un don"
		case .Logout:
			return "Se déconnecter"
		}
	}
}

