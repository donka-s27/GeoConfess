//
//  FCMPushNotificationService.swift
//  GeoConfess
//
// Created by Vladimir Kuznetsov on June 5, 2016.
// Copyright (c) 2016 KTO. All rights reserved.
//

import Foundation
import Firebase
import FirebaseInstanceID
import FirebaseMessaging

/// Manages integration with **Firebase Cloud Messaging** (FCM).
///
/// Backend uses user’s topic `"/topics/user-{user_id}"` to identify recipients
/// of push notification, everybody who is subscribed to this topic will receive
/// push notification.
///
/// In this case we are not bored with device token management on the backend.
/// To push notification to iOS and Android all we need is to subscribe on user
/// topic from mobile apps and send notification to FCM user topic from backend.
final class FCMPushNotificationService {

	// MARK: - Initializing Notification Service

	init() {
		FIRApp.configure()
	}
	
	/// APNS device token.
	var deviceToken: NSData? {
		didSet {
			syncDeviceToken()
		}
	}
	
	private func syncDeviceToken() {
		FIRInstanceID.instanceID().setAPNSToken(deviceToken!, type: tokenType)
	}
	
	/// Returns token type based on current app configuration
	private var tokenType: FIRInstanceIDAPNSTokenType {
		switch App.instance.configuration {
		case .Distribution:
			return .Sandbox
		case .Test:
			return .Prod
		}
	}
	
	// MARK: - Subscribing to Topics
	
	/// High level method for subscribing to user pushes.
	/// User pushes are sent to "/topics/user-{userId}".
	func subscribeToUserPushes(user: User) {
		subscribeToTopicPushes("user-\(user.id)")
	}
	
	/// High level method for unsubscribing from user pushes.
	func unsubscribeFromUserPushes(user: User) {
		unsubscribeFromTopicPushes("user-\(user.id)")
	}

	/// High level method for subscribing to topics.
	private func subscribeToTopicPushes(topic: String) {
		guard App.instance.isNetworkReachable else { return }
		FIRMessaging.messaging().subscribeToTopic("/topics/\(topic)")
	}
	
	private func unsubscribeFromTopicPushes(topic: String) {
		guard App.instance.isNetworkReachable else { return }
		FIRMessaging.messaging().unsubscribeFromTopic("/topics/\(topic)")
	}
}
