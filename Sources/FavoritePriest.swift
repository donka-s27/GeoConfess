//
//  FavoritePriest.swift
//  GeoConfess
//
//  Created by Donka on 5/2/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import Alamofire
import SwiftyJSON

/// Stores a favorite priest.
/// See [docs](https://geoconfess.herokuapp.com/apidoc/V1/favorites.html)
final class FavoritePriest {
	
	/// Unique identifier for this favorite object.
	let id: UInt64
	
	/// Priest has location if he is active right *now*.
	let priest: UserInfo
	
	private init(fromJSON json: [String: JSON]) {
		self.id = json["id"]!.resourceID!
		self.priest = UserInfo(fromJSON: json["priest"]!.dictionary!)
	}
	
	// MARK: - Backend Operations
	
	/// Returns all favorites of current user.
	/// No internal caching is performed.
	static func getAllForCurrentUser(
		completion: (favoritePriests: [FavoritePriest]?, error: Error?) -> Void) {
		
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/favorites.html
		let url = "\(App.serverAPI)/favorites";
		let parameters: [String : AnyObject] = [
			"access_token": User.current.oauth.accessToken
		]
		Alamofire.request(.GET, url, parameters: parameters).validate().responseJSON {
			response in
			switch response.result {
			case .Success(let value):
				let favoritesJSON: [JSON] = JSON(value).array!
				var favorites = [FavoritePriest]()
				for favoriteJSON in favoritesJSON {
					favorites.append(FavoritePriest(fromJSON: favoriteJSON.dictionary!))
				}
				completion(favoritePriests: favorites, error: nil)
			case .Failure(let error):
				log("Favorites error: \(error.readableDescription)")
				completion(favoritePriests: nil, error: Error(causedBy: error))
			}
		}
	}
	
	/// Deletes this favorite priest entry.
	func delete(completion: (error: Error?) -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/favorites/destroy.html
		let url = "\(App.serverAPI)/favorites/\(id)";
		let parameters: [String : AnyObject] = [
			"access_token": User.current.oauth.accessToken
		]
		Alamofire.request(.DELETE, url, parameters: parameters).validate().responseJSON {
			response in
			switch response.result {
			case .Success:
				completion(error: nil)
			case .Failure(let error):
				log("Delete favorite ERROR:\n\(error)")
				completion(error: Error(causedBy: error))
			}
		}
	}
}
