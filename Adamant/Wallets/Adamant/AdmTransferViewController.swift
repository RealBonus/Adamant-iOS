//
//  AdmTransferViewController.swift
//  Adamant
//
//  Created by Anokhov Pavel on 18.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka
import SafariServices

// MARK: - Localization
extension String.adamantLocalized {
    struct transferAdm {
        static func accountNotFoundAlertTitle(for address: String) -> String {
            return String.localizedStringWithFormat(NSLocalizedString("TransferScene.unsafeTransferAlert.title", comment: "Transfer: Alert title: Account not found or not initiated. Alert user that he still can send money, but need to double ckeck address"), address)
        }
            
        static let accountNotFoundAlertBody = NSLocalizedString("TransferScene.unsafeTransferAlert.body", comment: "Transfer: Alert body: Account not found or not initiated. Alert user that he still can send money, but need to double ckeck address")
        
        private init() {}
    }
}

class AdmTransferViewController: TransferViewControllerBase {
	// MARK: Properties
	
	private var skipValueChange: Bool = false
	
	static let invalidCharactersSet = CharacterSet.decimalDigits.inverted
	
	// MARK: Sending
	
	override func sendFunds() {
		guard let service = service as? AdmWalletService, let recipient = recipientAddress, let amount = amount else {
			return
		}
		
        let comments: String
        if let row: TextAreaRow = form.rowBy(tag: BaseRows.comments.tag), let text = row.value {
            comments = text
        } else {
            comments = ""
        }
        
        dialogService.showProgress(withMessage: String.adamantLocalized.transfer.transferProcessingMessage, userInteractionEnable: false)
        
        // Check recipient
        accountsProvider.getAccount(byAddress: recipient) { result in
            switch result {
            case .success(_):
                self.sendFundsInternal(service: service, recipient: recipient, amount: amount, comments: comments)
                
            case .notFound(_), .notInitiated(_), .dummy(_):
                let alert = UIAlertController(title: String.adamantLocalized.transferAdm.accountNotFoundAlertTitle(for: recipient),
                                              message: String.adamantLocalized.transferAdm.accountNotFoundAlertBody,
                                              preferredStyle: .alert)
                
                if let url = URL(string: NewChatViewController.faqUrl) {
                    let faq = UIAlertAction(title: String.adamantLocalized.newChat.whatDoesItMean,
                                            style: UIAlertAction.Style.default) { [weak self] _ in
                        let safari = SFSafariViewController(url: url)
                        safari.preferredControlTintColor = UIColor.adamant.primary
                        self?.present(safari, animated: true, completion: nil)
                    }
                    
                    alert.addAction(faq)
                }
                
                let send = UIAlertAction(title: BaseRows.sendButton.localized,
                                         style: .default) { _ in
                    self.dialogService.showProgress(withMessage: String.adamantLocalized.transfer.transferProcessingMessage, userInteractionEnable: false)
                    self.sendFundsInternal(service: service, recipient: recipient, amount: amount, comments: comments)
                }
                
                let cancel = UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil)
                
                alert.addAction(send)
                alert.addAction(cancel)
                
                DispatchQueue.main.async {
                    self.present(alert, animated: true, completion: nil)
                    self.dialogService.dismissProgress()
                }
                
            case .invalidAddress(_), .serverError(_), .networkError(_):
                self.dialogService.showWarning(withMessage: result.localized)
            }
        }
	}
    
    private func sendFundsInternal(service: AdmWalletService, recipient: String, amount: Decimal, comments: String) {
        service.sendMoney(recipient: recipient, amount: amount, comments: comments) { [weak self] result in
            switch result {
            case .success(let result):
                service.update()
                
                guard let vc = self else {
                    break
                }
                
                vc.dialogService?.showSuccess(withMessage: String.adamantLocalized.transfer.transferSuccess)
                
                let detailsVC = self?.router.get(scene: AdamantScene.Wallets.Adamant.transactionDetails) as? AdmTransactionDetailsViewController
                detailsVC?.transaction = result
                
                if comments.count > 0 {
                    detailsVC?.comment = comments
                }
                
                // MARK: Sender, you
                detailsVC?.senderName = String.adamantLocalized.transactionDetails.yourAddress
                
                // MARK: Get recipient
                if let recipientName = self?.recipientName {
                    detailsVC?.recipientName = recipientName
                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: result, detailsViewController: detailsVC)
                } else if let accountsProvider = self?.accountsProvider {
                    accountsProvider.getAccount(byAddress: recipient) { accResult in
                        switch accResult {
                        case .success(let account):
                            detailsVC?.recipientName = account.name
                            vc.delegate?.transferViewController(vc, didFinishWithTransfer: result, detailsViewController: detailsVC)
                            
                        default:
                            vc.delegate?.transferViewController(vc, didFinishWithTransfer: result, detailsViewController: detailsVC)
                        }
                    }
                } else {
                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: result, detailsViewController: detailsVC)
                }
                
            case .failure(let error):
                guard let dialogService = self?.dialogService else {
                    break
                }
                
                dialogService.dismissProgress()
                dialogService.showRichError(error: error)
            }
        }
    }
	
	
	// MARK: Overrides
	
	private var _recipient: String?
	
	override var recipientAddress: String? {
		set {
			if let recipient = newValue, let first = recipient.first, first != "U" {
				_recipient = "U\(recipient)"
			} else {
				_recipient = newValue
			}
			
			if let row: TextRow = form.rowBy(tag: BaseRows.address.tag) {
				row.value = _recipient
				row.updateCell()
			}
		}
		get {
			return _recipient
		}
	}
	
	override func recipientRow() -> BaseRow {
		let row = TextRow() {
			$0.tag = BaseRows.address.tag
			$0.cell.textField.placeholder = String.adamantLocalized.newChat.addressPlaceholder
			$0.cell.textField.keyboardType = .numberPad
			
			if let recipient = recipientAddress {
				let trimmed = recipient.components(separatedBy: AdmTransferViewController.invalidCharactersSet).joined()
				$0.value = trimmed
			}
			
			let prefix = UILabel()
			prefix.text = "U"
			prefix.sizeToFit()
            
            let view = UIView()
			view.addSubview(prefix)
			view.frame = prefix.frame
			$0.cell.textField.leftView = view
			$0.cell.textField.leftViewMode = .always
			
			if recipientIsReadonly {
				$0.disabled = true
//                prefix.isEnabled = false
			}
		}.cellUpdate { (cell, row) in
			if let text = cell.textField.text {
                cell.textField.text = text.components(separatedBy: AdmTransferViewController.invalidCharactersSet).joined()
			}
		}.onChange { [weak self] row in
			if let skip = self?.skipValueChange, skip {
				self?.skipValueChange = false
				return
			}
			
			if let text = row.value {
				let trimmed = text.components(separatedBy: AdmTransferViewController.invalidCharactersSet).joined()
				
				if text != trimmed {
					self?.skipValueChange = true
					
					DispatchQueue.main.async {
						row.value = trimmed
						row.updateCell()
					}
				}
			}
			
			self?.validateForm()
		}
		
		return row
	}
	
	override func validateRecipient(_ address: String) -> Bool {
		let fixedAddress: String
		if let first = address.first, first != "U" {
			fixedAddress = "U\(address)"
		} else {
			fixedAddress = address
		}
		
		switch AdamantUtilities.validateAdamantAddress(address: fixedAddress) {
		case .valid:
			return true
			
		case .system, .invalid:
			return false
		}
	}
	
	override func handleRawAddress(_ address: String) -> Bool {
        guard let admAddress = address.getAdamantAddress() else {
            return false
        }
        
        if let row: TextRow = form.rowBy(tag: BaseRows.address.tag) {
            row.value = admAddress.address
            row.updateCell()
        }
        
        return true
	}
    
    override func defaultSceneTitle() -> String? {
        return String.adamantLocalized.wallets.sendAdm
    }
}
