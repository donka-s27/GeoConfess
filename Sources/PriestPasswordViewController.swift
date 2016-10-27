//
//  PriestPasswordViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on 3/5/16.
//  Copyright © 2016 DanMobile. All rights reserved.
//

import Foundation
import UIKit
import AWSMobileAnalytics
import AWSCognito
import AWSS3
import AWSCore
import Photos
import MobileCoreServices
import AssetsLibrary
import Alamofire
import SwiftyJSON

final class PriestPasswordViewController: AppViewController,
	UITextFieldDelegate, UIActionSheetDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

		resignFirstResponderWithOuterTouches(priestPasswordField, priestConfirmField)
		setUploadingAnimation(false)
    }
	
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        precondition(priest != nil)
		
		if runOnViewWillAppear != nil {
			runOnViewWillAppear!()
			runOnViewWillAppear = nil
		}
    }
	
	// MARK: - Entering Priest Information
	
	@IBOutlet weak private var priestPasswordField: UITextField!
	@IBOutlet weak private var priestConfirmField: UITextField!
	@IBOutlet weak private var notificationTick: Tick!
	
	@IBOutlet weak private var signUpButton: UIButton!
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	shouldChangeCharactersInRange range: NSRange, replacementString replacement: String)
	-> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)
		
		switch textField {
		case priestPasswordField:
			priest.password = textAfterChange
		case priestConfirmField:
			priest.confirmedPassword = textAfterChange
		default:
			preconditionFailure("Unexpected UITextField")
		}
		enableOrDisableSignUpButton()
		return true
	}
	
	/// Called when 'return' key pressed. return NO to ignore.
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
		case priestPasswordField:
			priestConfirmField.becomeFirstResponder()
		case priestConfirmField:
			priestConfirmField.resignFirstResponder()
		default:
			preconditionFailure("Unexpected UITextField")
		}
		return true
	}
	
	@IBAction private func notificationTickChanged(sender: Tick) {
		priest.nearbyPriestsNotification = sender.on
	}
	
	// MARK: - Signing Up Priest

	private var priest: PriestSignUp!
	private var runOnViewWillAppear: (() -> Void)?

	func willEnterPasswordFor(priest: PriestSignUp) {
		self.priest = priest
		
		// This hack is required because we *also* present internal view controllers
		// from this one -- so viewWillAppear will be called multiple times.
		runOnViewWillAppear = {
			self.priest.password = ""
			self.priest.confirmedPassword = ""
			self.priest.nearbyPriestsNotification = false
			self.priest.receiveNewsletter = true
			
			self.priestPasswordField.text = nil
			self.priestConfirmField.text = nil
			self.notificationTick.on = false
			self.enableOrDisableSignUpButton()
			
			self.priestPasswordField.becomeFirstResponder()
		}
	}
	
	private var shouldEnableSignUpButton: Bool {
		let errors = priest.detectErrors()
		for error in errors {
			switch error {
			case .Undefined(let p) where p == .CelebretURL:
				break
			case .Undefined:
				return false
			case .Malformed(let p) where p == .Password || p == .ConfirmedPassword:
				break
			case .Malformed:
				return false
			}
		}
		return true
	}
	
	private func enableOrDisableSignUpButton() {
		if shouldEnableSignUpButton {
			signUpButton.enabled = true
			signUpButton.backgroundColor = UIButton.enabledColor
		} else {
			signUpButton.enabled = false
			signUpButton.backgroundColor = UIButton.disabledColor
		}
	}

    @IBAction func signUpButtonTapped(sender: AnyObject) {
		precondition(shouldEnableSignUpButton)
		let errors = priest.detectErrors()
		
		guard !errors.contains(.Malformed(.Password)) else {
			showAlert(
				title: "Mot de passe",
				message: "Le mot de passe doit faire plus de 6 caractères.") {
					self.priestPasswordField.becomeFirstResponder()
			}
			return
		}
		guard !errors.contains(.Malformed(.ConfirmedPassword)) else {
			showAlert(
				title: "Confirmation mot de passe",
				message: "Les mots de passe doivent être identiques.") {
					self.priestConfirmField.becomeFirstResponder()
			}
			return
		}
        guard !errors.contains(.Undefined(.CelebretURL)) else {
			showAlert(
				title: "Celebret",
				message: "Veuillez uploader votre celebret pour continuer.")
            return
        }
		signUpPriest()
	}
	
	private func signUpPriest() {
        showProgressHUD()
        priest.signUp(thenLogin: true) {
            result in
            self.hideProgressHUD()
            switch result {
            case .Success:
                self.performSegueWithIdentifier("enterApp", sender: self)
            case .Failure(let error):
                self.showAlertForError(error)
            }
        }
	}
	
	// MARK: - Taking a Photo
	
	@IBOutlet weak private var containProgressView: UIView!
	@IBOutlet weak private var progressView: UIProgressView!

	@IBAction func cameraButtonTapped(sender: UIButton) {
		let actionSheet = UIActionSheet(
			title: "Souhaitez-vous",
			delegate: self,
			cancelButtonTitle: "Cancel",
			destructiveButtonTitle: nil,
			otherButtonTitles: "Prendre une photo", "Choisir dans la galerie")
		actionSheet.showInView(view)
	}
	
	func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
		switch buttonIndex {
		case 0:
			break // Cancel button.
		case 1:
			takeAPhoto()
		case 2:
			selectPhotoFromGallery()
		default:
			preconditionFailure("Unexpected button")
		}
	}
	
	private func selectPhotoFromGallery() {
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .PhotoLibrary
		imagePicker.allowsEditing = true
		imagePicker.delegate = self
		presentViewController(imagePicker, animated: true, completion: nil)
	}

	private func takeAPhoto() {
		guard UIImagePickerController.isSourceTypeAvailable(.Camera) else {
			showAlert(title: "Erreur", message: "L'appareil photo est indisponible!")
			return
		}
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .Camera
		imagePicker.allowsEditing = true
		imagePicker.delegate = self
		presentViewController(imagePicker, animated: true, completion: nil)
	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	func imagePickerController(
		picker: UIImagePickerController,
		didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let image = info[UIImagePickerControllerOriginalImage] as! UIImage
		let imageData = UIImageJPEGRepresentation(image, 0.1)!
		
		let tmpDir = NSTemporaryDirectory()
		let imagePath = tmpDir.stringByAppendingPathComponent("photo.jpg")
		imageData.writeToFile(imagePath, atomically: true)
		let imageFileURL = NSURL(fileURLWithPath: imagePath)
		
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "dd_MM_yyyy_hh_mm_ss"
		let imageID = "\(dateFormatter.stringFromDate(NSDate())).jpg"
		
		uploadImageToAWS(imageFileURL, imageID: imageID)
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	private func uploadImageToAWS(imageFile: NSURL, imageID: String) {
		let uploadRequest = AWSS3TransferManagerUploadRequest()
		uploadRequest.ACL = AWSS3ObjectCannedACL.PublicRead
		uploadRequest.bucket = "geoconfessapp"
		uploadRequest.contentType = "image/jpeg"
		uploadRequest.key  = imageID
		uploadRequest.body = imageFile

		uploadRequest.uploadProgress = {
			(bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) in
			dispatch_sync(dispatch_get_main_queue()) {
				let sent = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
				self.progressView.progress = sent
				print(String(format:"Uploading photo %.0f%%", sent * 100))
			}
		}

		let uploading = "Uploading photo"
		log("\(uploading)...")
		setUploadingAnimation(true)
		let transferManager = AWSS3TransferManager.defaultS3TransferManager()
		let upload = transferManager.upload(uploadRequest)
		upload.continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: {
			task -> AnyObject? in
			guard task.error == nil else {
				logError("Upload error: \(task.error)")
				return nil
			}
			let s3URL = "https://\(uploadRequest.bucket!).s3.amazonaws.com/\(imageID)"
			self.priest.celebretURL = NSURL(string: s3URL)!
			log("\(uploading)... OK (URL: \(self.priest.celebretURL))")
			self.setUploadingAnimation(false)
			self.enableOrDisableSignUpButton()
			return nil
		})
	}
	
	private func setUploadingAnimation(animation: Bool) {
		if animation {
			view.alpha = 0.7
			view.userInteractionEnabled = false
			containProgressView.hidden = false
			progressView.progress = 0.0
		} else {
			view.alpha = 1.0
			view.userInteractionEnabled = true
			containProgressView.hidden = true
			progressView.progress = 0.0
		}
	}
}
