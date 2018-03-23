//
//  ButtonsStripeView.swift
//  Adamant
//
//  Created by Anokhov Pavel on 23.03.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import MyLittlePinpad

// MARK: - Button types
enum StripeButtonType: Int, Equatable {
	case pinpad
	case qrCameraReader
	//	case qrPhotoReader
	
	var image: UIImage {
		switch self {
		case .pinpad:
			return UIImage(named: "Stripe_Pinpad")!
			
		case .qrCameraReader:
			return UIImage(named: "Stripe_QRCamera")!
		}
	}
}

typealias Stripe = [StripeButtonType]


// MARK: - Delegate
protocol ButtonsStripeViewDelegate: class {
	func buttonsStripe(_ stripe: ButtonsStripeView, didTapButton button: StripeButtonType)
}


// MARK: - View
class ButtonsStripeView: UIView {
	// MARK: IBOutlet
	@IBOutlet weak var stripeStackView: UIStackView!
	
	// MARK: Properties
	weak var delegate: ButtonsStripeViewDelegate?
	private var buttons: [RoundedButton]? = nil
	
	var stripe: Stripe? = nil {
		didSet {
			for aView in stripeStackView.subviews {
				aView.removeFromSuperview()
			}
			
			guard let stripe = stripe else {
				stripeStackView.addArrangedSubview(UIView())
				buttons = nil
				return
			}
			
			buttons = [RoundedButton]()
			
			for aButton in stripe {
				let button = RoundedButton()
				button.tag = aButton.rawValue
				button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
				
				button.setImage(aButton.image, for: .normal)
				
				button.imageView!.contentMode = .scaleAspectFit
				button.clipsToBounds = true
				
				button.normalBackgroundColor = buttonsNormalColor
				button.highlightedBackgroundColor = buttonsHighlightedColor
				button.backgroundColor = buttonsNormalColor
				
				button.roundingMode = buttonsRoundingMode
				button.layer.borderWidth = buttonsBorderWidth
				button.layer.borderColor = buttonsBorderColor?.cgColor
				
				button.heightAnchor.constraint(equalToConstant: buttonsSize).isActive = true
				button.widthAnchor.constraint(equalToConstant: buttonsSize).isActive = true
				button.constraints.forEach({$0.identifier = "wh"})
				
				stripeStackView.addArrangedSubview(button)
				buttons?.append(button)
			}
		}
	}
	
	// MARK: Buttons properties
	var buttonsBorderColor: UIColor? = nil {
		didSet {
			if let buttons = buttons {
				buttons.forEach { $0.borderColor = buttonsBorderColor }
			}
		}
	}
	
	var buttonsBorderWidth: CGFloat = 0.0 {
		didSet {
			if let buttons = buttons {
				buttons.forEach { $0.borderWidth = buttonsBorderWidth }
			}
		}
	}
	
	var buttonsRoundingMode: RoundingMode = .none {
		didSet {
			if let buttons = buttons {
				buttons.forEach { $0.roundingMode = buttonsRoundingMode }
			}
		}
	}
	
	var buttonsNormalColor: UIColor? = nil {
		didSet {
			if let buttons = buttons {
				buttons.forEach { $0.normalBackgroundColor = buttonsNormalColor }
			}
		}
	}
	
	var buttonsHighlightedColor: UIColor? = nil {
		didSet {
			if let buttons = buttons {
				buttons.forEach { $0.highlightedBackgroundColor = buttonsHighlightedColor }
			}
		}
	}
	
	var buttonsSize: CGFloat = 50.0 {
		didSet {
			buttons?.flatMap({ $0.constraints }).filter({ $0.identifier == "wh" }).forEach({ $0.constant = buttonsSize })
		}
	}
	
	// MARK: Delegate
	@objc private func buttonTapped(_ sender: UIButton) {
		if let button = StripeButtonType(rawValue: sender.tag) {
			delegate?.buttonsStripe(self, didTapButton: button)
		}
	}
}


// MARK: Adamant config
extension ButtonsStripeView {
	static func adamantConfigured() -> ButtonsStripeView {
		guard let view = UINib(nibName: "ButtonsStripe", bundle: nil).instantiate(withOwner: nil, options: nil).first as? ButtonsStripeView else {
			fatalError("Can't get UINib")
		}
		
		view.buttonsBorderColor = UIColor.adamantSecondary
		view.buttonsBorderWidth = 1
		view.buttonsSize = 50
		view.buttonsRoundingMode = .circle
		view.buttonsHighlightedColor = UIColor.adamantPinpadHighlightButton
		view.buttonsNormalColor = .white
		view.stripeStackView.spacing = 15
		
		return view
	}
}
