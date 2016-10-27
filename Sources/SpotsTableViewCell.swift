//
//  SpotsTableViewCell.swift
//  geoconfess
//
//  Created  by Andreas Muller on April 16, 2016.
//  Reviewed by Dan Dobrev on June 8, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Cell used in the `SpotsTableViewController`.
final class SpotsTableViewCell: UITableViewCell {

    @IBOutlet weak var spotNameLabel: UILabel!
    @IBOutlet weak var recurrenceLabel: UILabel!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
	
	/// Configure the view for the selected state
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
	
	weak var spotEditor: SpotEditor!
	
	func setSpotEditor(spotEditor: SpotEditor, forIndexPath indexPath: NSIndexPath) {
		self.spotEditor = spotEditor
		spotNameLabel.text   = spotEditor.spot.name
		recurrenceLabel.text = spotEditor.recurrence?.displayDescription ?? ""

		if indexPath.row % 2 == 0 {
			contentView.backgroundColor = UIColor(
				red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
			spotNameLabel.textColor = UIColor.darkGrayColor()
			recurrenceLabel.textColor = UIColor.darkGrayColor()
			editButton.setImage(UIImage(named: "Pen"), forState: .Normal)
			trashButton.setImage(UIImage(named: "Trash"), forState: .Normal)
		} else {
			contentView.backgroundColor = UIColor(
				red: 200/255, green: 70/255, blue: 83/255, alpha: 1)
			spotNameLabel.textColor = UIColor.whiteColor()
			recurrenceLabel.textColor = UIColor.whiteColor()
			editButton.setImage(UIImage(named: "Alpha Pen"), forState: .Normal)
			trashButton.setImage(UIImage(named: "Alpha Trash"), forState: .Normal)
		}
		
		editButton.addTarget(
			self, action: #selector(self.spotEditButtonTapped(_:)),
			forControlEvents: .TouchUpInside)
		trashButton.addTarget(
			self, action: #selector(self.spotTrashButtonTapped(_:)),
			forControlEvents: .TouchUpInside)
	}
	
	var delegate: SpotsTableViewCellDelegate?
	
	@objc private func spotEditButtonTapped(sender: UIButton) {
		assert(sender === editButton)
		delegate?.spotEditButtonTapped(self)
	}

	@objc private func spotTrashButtonTapped(sender: UIButton) {
		assert(sender === trashButton)
		delegate?.spotTrashButtonTapped(self)
	}
}

/// Delegates cell's buttons actions.
protocol SpotsTableViewCellDelegate {
	
	func spotEditButtonTapped(cell: SpotsTableViewCell)
	func spotTrashButtonTapped(cell: SpotsTableViewCell)
}
