//
//  NinthTableViewCell.swift
//  GeoConfess
//
//  Created by Viktor Pavlov on 6/4/16.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

final class NinthTableViewCell : UITableViewCell {
	
	@IBOutlet weak var textlabel: UILabel!
	@IBOutlet weak var arrow: UIImageView!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		// Initialization code.
	}
	
	override func setSelected(selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		// Configure the view for the selected state.
	}
	
	func fillForMenuMood(menuMood: MenuMood) {
		switch menuMood {
		case .Standard:
			textlabel.text = "Pourquoi se confesser"
		default:
			textlabel.text = "Pourquoi se confesser"
		}
	}
}