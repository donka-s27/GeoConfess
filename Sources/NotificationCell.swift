//
//  NotificationCell.swift
//  GeoConfess
//
//  Created  by Dan on April 19, 2016.
//  Reviewed by Dan Dobrev on June 2, 2016.
//  Copyright © 2016 KOT. All rights reserved.
//

import UIKit

/// A row in the notifications table.
/// See `NotificationsViewController` for more information.
final class NotificationCell: UITableViewCell {
	
    @IBOutlet weak private var titleLabel: UILabel!
    @IBOutlet weak private var statusLabel: UILabel!
	@IBOutlet weak private var iconImage: UIImageView!
    @IBOutlet weak private var distanceLabel: UILabel!
	
	@IBOutlet weak private var goToImage: UIImageView!
    @IBOutlet weak private var goToLabel: UILabel!
	
    private var notification: Notification!
	
	override func prepareForReuse() {
		super.prepareForReuse()
		
		setSelected(false, animated: false)
		distanceLabel.hidden = false
		goToLabel.hidden = false
		goToImage.hidden = false
	}
	
    /// Configure the view for the selected state.
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            self.titleLabel.textColor    = UIColor.whiteColor()
            self.statusLabel.textColor   = UIColor.whiteColor()
            self.distanceLabel.textColor = UIColor.whiteColor()
            self.goToLabel.textColor     = UIColor.whiteColor()
            self.iconImage.image = UIImage(named: "logo-blanc-liste");
            self.backgroundColor = UIColor.redColor()
		} else {
			setUnread(notification?.unread ?? true)
            self.iconImage.image = UIImage(named: "logo-couleur-liste");
        }
    }
    
    func setNotification(notification: Notification) {
		self.notification = notification
		let user = User.current!
		
		selectionStyle = .None
		setUnread(notification.unread)
		setDistanceLabel(notification)
		
		func title(name: String)  -> String { return name.uppercaseString }
		func status(name: String) -> String { return name.uppercaseString }
		
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent, .Admin:
				titleLabel.text = title(meetRequest.priest.name)
				switch meetRequest.status {
				case .Pending:
					statusLabel.text = status("Demande envoyée")
					goToLabel.text   = "Voir la fiche"
				case .Accepted:
					statusLabel.text = status("Demande acceptée")
					goToLabel.text   = "Voir conversation"
				case .Refused:
					statusLabel.text = status("Demande refusée")
					goToLabel.text   = "Voir la fiche"
				}
			case .Priest:
				titleLabel.text = title(meetRequest.penitent.name)
				switch meetRequest.status {
				case .Pending:
					statusLabel.text = status("Demande reçue")
					goToLabel.text   = "Répondre"
				case .Accepted:
					statusLabel.text = status("Demande acceptée")
					goToLabel.text   = "Voir conversation"
				case .Refused:
					statusLabel.text = status("Demande refusée")
					goToLabel.hidden = true
					goToImage.hidden = true
				}
			}
		case .MessageNotification(let message):
			titleLabel.text = title(message.sender.name)
			switch user.role {
			case .Penitent, .Priest, .Admin:
				statusLabel.text = status("Message")
				goToLabel.text   = "Voir conversation"
			}
		}
    }

	/// Unread notifications will be shown in black.
	private func setUnread(unread: Bool) {
		if unread {
			titleLabel.textColor    = UIColor.blackColor()
			statusLabel.textColor   = UIColor.blackColor()
			distanceLabel.textColor = UIColor.blackColor()
		} else {
			titleLabel.textColor    = UIColor.lightGrayColor()
			statusLabel.textColor   = UIColor.lightGrayColor()
			distanceLabel.textColor = UIColor.lightGrayColor()
		}
		goToLabel.textColor     = App.tintColor
		backgroundColor = UIColor.whiteColor()
	}

	private func setDistanceLabel(notification: Notification) {
		let user = User.current!

		let otherUserLocationOrNil: CLLocationCoordinate2D?
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent, .Admin:
				otherUserLocationOrNil = meetRequest.priest.location
			case .Priest:
				otherUserLocationOrNil = meetRequest.penitent.location
			}
		case .MessageNotification:
			otherUserLocationOrNil = nil
		}
		
		guard let otherUserLocation = otherUserLocationOrNil,
			  let userLocation = User.current.location else {
			distanceLabel.hidden = true
			return
		}
		let dist = userLocation.distanceFromLocation(CLLocation(at: otherUserLocation))
		distanceLabel.text = String(format: "à %.0f mètres", dist)
    }
}