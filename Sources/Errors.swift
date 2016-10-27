//
//  Errors.swift
//  GeoConfess
//
//  Created by Donka on June 29, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// MARK: - Error Class

/// The main error abstraction used by the app.
/// All meaningful errors are mapped to the `Error.Code` enum.
final class Error: ErrorType, CustomStringConvertible {
	
	enum Code: CustomStringConvertible {
		case internetConnectivityError
		case restObjectNotFound
		case jsonCodecError
		case authenticationFailed
		case coreLocationError(CLError)
		case unexpectedClientError
		case unexpectedServerError
		
		var description: String {
			switch self {
			case .internetConnectivityError:
				return "Internet Connectivity Error"
			case .restObjectNotFound:
				return "REST Object Not Found"
			case .jsonCodecError:
				return "JSON Codec Error"
			case .authenticationFailed:
				return "Authentication Failed"
			case .coreLocationError(let clerror):
				return "Core Location Error: \(clerror)"
			case .unexpectedClientError:
				return "Unexpected Client Error"
			case .unexpectedServerError:
				return "Unexpected Server Error"
			}
		}
	}

	let code: Error.Code
	let causedBy: NSError?
	
	convenience init(causedBy error: NSError) {
		let code: Error.Code
		switch error.domain {
		case NSCocoaErrorDomain:
			code = .unexpectedClientError
		case NSURLErrorDomain:
			switch error.code {
			case NSURLErrorCancelled, NSURLErrorBadURL:
				code = .unexpectedClientError
			case NSURLErrorTimedOut:
				code = .internetConnectivityError
			case NSURLErrorUnsupportedURL:
				code = .unexpectedClientError
			case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
				code = .internetConnectivityError
			case NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed:
				code = .internetConnectivityError
			case NSURLErrorHTTPTooManyRedirects, NSURLErrorResourceUnavailable:
				code = .unexpectedServerError
			case NSURLErrorNotConnectedToInternet:
				code = .internetConnectivityError
			case NSURLErrorRedirectToNonExistentLocation:
				code = .unexpectedServerError
			case NSURLErrorBadServerResponse:
				code = .unexpectedServerError
			case NSURLErrorUserCancelledAuthentication:
				code = .unexpectedServerError
			case NSURLErrorUserAuthenticationRequired:
				code = .unexpectedServerError
			case NSURLErrorZeroByteResource:
				code = .unexpectedServerError
			case NSURLErrorCannotDecodeRawData, NSURLErrorCannotDecodeContentData:
				code = .unexpectedServerError
			case NSURLErrorCannotParseResponse:
				code = .unexpectedServerError
			default:
				code = .unexpectedClientError
			}
		case Alamofire.Error.Domain:
			switch Alamofire.Error.Code(rawValue: error.code)! {
			case .InputStreamReadFailed, .OutputStreamWriteFailed:
				code = .unexpectedServerError
			case .ContentTypeValidationFailed:
				code = .unexpectedServerError
			case .StatusCodeValidationFailed:
				// See: http://www.restapitutorial.com/httpstatuscodes.html
				let statusCodeKey = Alamofire.Error.UserInfoKeys.StatusCode
				switch error.userInfo[statusCodeKey] as! Int {
				case 401:
					// Unauthorized error.
					code = .authenticationFailed
				case 400, 402...499:
					// Client errors.
					code = .unexpectedClientError
				case 500...598:
					// Server errors.
					code = .unexpectedServerError
				case 599: 
					// Network connect timeout error.
					code = .internetConnectivityError
				default:
					code = .unexpectedServerError
				}
			case .DataSerializationFailed, .StringSerializationFailed:
				code = .unexpectedServerError
			case .JSONSerializationFailed, .PropertyListSerializationFailed:
				code = .unexpectedServerError
			}
		case SwiftyJSON.ErrorDomain:
			// See: https://goo.gl/UmVzl5
			code = .jsonCodecError
		default:
			code = .unexpectedClientError
		}
		self.init(code: code, causedBy: error)
	}

	init(code: Error.Code, causedBy error: NSError? = nil) {
		self.code = code
		self.causedBy = error
		switch code {
		case .unexpectedServerError, .unexpectedClientError:
			// We should log unexpected errors explicitly.
			if error != nil {
				log("Unexpected ERROR\n\(error!.readableDescription)")
			} else {
				log("Unexpected ERROR without cause")
			}
		default:
			break
		}
	}
	
	var localizedDescription: String {
		var ref = ""
		if let error = causedBy {
			ref = "(\(error.domain), \(error.code))"
		}
		switch code {
		case .internetConnectivityError:
			return "Impossible de se connecter à internet."
		case .restObjectNotFound:
			return "Erreur de serveur inattendue."
		case .authenticationFailed:
			return "Échec de l'authentification."
		case .coreLocationError:
			return "Erreur interne d'application. Veuillez réessayer plus tard. \(ref)"
		case .unexpectedClientError:
			return "Erreur interne d'application. Veuillez réessayer plus tard. \(ref)"
		case .unexpectedServerError, .jsonCodecError:
			return "Erreur interne du serveur. Veuillez réessayer plus tard. \(ref)"
		}
	}
	
	var description: String {
		var lines = [String]()
		lines.append(code.description)
		if let error = causedBy {
			lines.append(error.readableDescription)
		}
		return lines.joinWithSeparator("\n")
	}
}

// MARK: - NSError Extensions

extension NSError {
	
	var readableDescription: String {
		let constant = errorCodeConstant(code, at: domain)
		var lines = [String]()
		lines.append("Error Domain: \(domain)")
		lines.append("Error Code: \(code) (\(constant))")
		if let errorDescription = userInfo[NSLocalizedDescriptionKey] {
			lines.append("Error Description: \(errorDescription)")
		}
		return lines.joinWithSeparator("\n")
	}
}

/// Converts the specified error code to the corresponding constant name.
///
/// References: 
/// * [NSHipster](http://nshipster.com/nserror/)
/// * [Alamofire](https://github.com/Alamofire/Alamofire/blob/master/Source/Error.swift)
private func errorCodeConstant(code: Int, at domain: String) -> String {
	switch domain {
	case NSCocoaErrorDomain:
		return "???"
	case NSURLErrorDomain:
		switch code {
		case NSURLErrorCancelled:
			return "NSURLErrorCancelled"
		case NSURLErrorBadURL:
			return "NSURLErrorBadURL"
		case NSURLErrorTimedOut:
			return "NSURLErrorTimedOut"
		case NSURLErrorUnsupportedURL:
			return "NSURLErrorUnsupportedURL"
		case NSURLErrorCannotFindHost:
			return "NSURLErrorCannotFindHost"
		case NSURLErrorCannotConnectToHost:
			return "NSURLErrorCannotConnectToHost"
		case NSURLErrorNetworkConnectionLost:
			return "NSURLErrorNetworkConnectionLost"
		case NSURLErrorDNSLookupFailed:
			return "NSURLErrorDNSLookupFailed"
		case NSURLErrorHTTPTooManyRedirects:
			return "NSURLErrorHTTPTooManyRedirects"
		case NSURLErrorResourceUnavailable:
			return "NSURLErrorResourceUnavailable"
		case NSURLErrorNotConnectedToInternet:
			return "NSURLErrorNotConnectedToInternet"
		case NSURLErrorRedirectToNonExistentLocation:
			return "NSURLErrorRedirectToNonExistentLocation"
		case NSURLErrorBadServerResponse:
			return "NSURLErrorBadServerResponse"
		case NSURLErrorUserCancelledAuthentication:
			return "NSURLErrorUserCancelledAuthentication"
		case NSURLErrorUserAuthenticationRequired:
			return "NSURLErrorUserAuthenticationRequired"
		case NSURLErrorZeroByteResource:
			return "NSURLErrorZeroByteResource"
		case NSURLErrorCannotDecodeRawData:
			return "NSURLErrorCannotDecodeRawData"
		case NSURLErrorCannotDecodeContentData:
			return "NSURLErrorCannotDecodeContentData"
		case NSURLErrorCannotParseResponse:
			return "NSURLErrorCannotParseResponse"
		default:
			return "???"
		}
	case kCLErrorDomain:
		let coreLocationError = CLError(rawValue: code)!
		return "\(coreLocationError)"
	case Alamofire.Error.Domain:
		switch Alamofire.Error.Code(rawValue: code)! {
		case .InputStreamReadFailed:
			return "InputStreamReadFailed"
		case .OutputStreamWriteFailed:
			return "OutputStreamWriteFailed"
		case .ContentTypeValidationFailed:
			return "ContentTypeValidationFailed"
		case .StatusCodeValidationFailed:
			return "StatusCodeValidationFailed"
		case .DataSerializationFailed:
			return "DataSerializationFailed"
		case .StringSerializationFailed:
			return "StringSerializationFailed"
		case .JSONSerializationFailed:
			return "JSONSerializationFailed"
		case .PropertyListSerializationFailed:
			return "PropertyListSerializationFailed"
		}
	default:
		return "???"
	}
}

// MARK: - CLError Extensions

extension CLError: CustomStringConvertible {
	
	public var description: String {
		switch self {
		case LocationUnknown:
			return "LocationUnknown"
		case Denied:
			return "Denied"
		case Network:
			return "Network"
		case HeadingFailure:
			return "HeadingFailure"
		case RegionMonitoringDenied:
			return "RegionMonitoringDenied"
		case RegionMonitoringFailure:
			return "RegionMonitoringFailure"
		case RegionMonitoringSetupDelayed:
			return "RegionMonitoringSetupDelayed"
		case RegionMonitoringResponseDelayed:
			return "RegionMonitoringResponseDelayed"
		case GeocodeFoundNoResult:
			return "GeocodeFoundNoResult"
		case GeocodeFoundPartialResult:
			return "GeocodeFoundPartialResult"
		case GeocodeCanceled:
			return "GeocodeCanceled"
		case DeferredFailed:
			return "DeferredFailed"
		case DeferredNotUpdatingLocation:
			return "DeferredNotUpdatingLocation"
		case DeferredAccuracyTooLow:
			return "DeferredAccuracyTooLow"
		case DeferredDistanceFiltered:
			return "DeferredDistanceFiltered"
		case DeferredCanceled:
			return "DeferredCanceled"
		case RangingUnavailable:
			return "RangingUnavailable"
		case RangingFailure:
			return "RangingFailure"
		}
	}
}

extension NSError {
	
	var coreLocationCode: CLError? {
		guard self.domain == kCLErrorDomain else { return nil }
		return CLError(rawValue: self.code)!
	}
}
