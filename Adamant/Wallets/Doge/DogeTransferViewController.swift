//
//  DogeTransferViewController.swift
//  Adamant
//
//  Created by Anton Boyarkin on 12/03/2019.
//  Copyright © 2019 Adamant. All rights reserved.
//

import UIKit
import Eureka

class DogeTransferViewController: TransferViewControllerBase {
    
    // MARK: Dependencies
    
    var chatsProvider: ChatsProvider!
    
    
    // MARK: Properties
    
    private var skipValueChange: Bool = false
    
    static let invalidCharacters: CharacterSet = CharacterSet.decimalDigits.inverted
    
    
    // MARK: Send
    
    override func sendFunds() {
        let comments: String
        if let row: TextAreaRow = form.rowBy(tag: BaseRows.comments.tag), let text = row.value {
            comments = text
        } else {
            comments = ""
        }
        
        guard let service = service as? DogeWalletService, let recipient = recipientAddress, let amount = amount, let dialogService = dialogService else {
            return
        }
        
        guard let sender = service.wallet?.address else {
            return
        }
        
        dialogService.showProgress(withMessage: String.adamantLocalized.transfer.transferProcessingMessage, userInteractionEnable: false)
        
        service.createTransaction(recipient: recipient, amount: amount) { [weak self] result in
            guard let vc = self else {
                dialogService.dismissProgress()
                dialogService.showError(withMessage: String.adamantLocalized.sharedErrors.unknownError, error: nil)
                return
            }
            
            switch result {
            case .success(let transaction):
                // MARK: 1. Send adm report
                if let reportRecipient = vc.admReportRecipient, let hash = transaction.txHash {
                    self?.reportTransferTo(admAddress: reportRecipient, amount: amount, comments: comments, hash: hash)
                }
                
                // MARK: 2. Send transaction
                service.sendTransaction(transaction) { result in
                    switch result {
                    case .success(let hash):
                        service.update()
                        
                        service.getTransaction(by: hash) { result in
                            switch result {
                            case .success(let dogeRawTransaction):
                                vc.dialogService.showSuccess(withMessage: String.adamantLocalized.transfer.transferSuccess)
                                
                                let transaction = dogeRawTransaction.asDogeTransaction(for: sender)
                                
                                guard let detailsVc = vc.router.get(scene: AdamantScene.Wallets.Doge.transactionDetails) as? DogeTransactionDetailsViewController else {
                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: nil)
                                    break
                                }
                                
                                detailsVc.transaction = transaction
                                detailsVc.service = service
                                
                                detailsVc.senderName = String.adamantLocalized.transactionDetails.yourAddress
                                
                                if let recipientName = self?.recipientName {
                                    detailsVc.recipientName = recipientName
                                } else if transaction.recipientAddress == sender {
                                    detailsVc.recipientName = String.adamantLocalized.transactionDetails.yourAddress
                                }
                                
                                if comments.count > 0 {
                                    detailsVc.comment = comments
                                }
                                
                                vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: detailsVc)
                                
                            case .failure(let error):
                                guard case let .internalError(message, _) = error, message == "No transaction" else {
                                    vc.dialogService.showRichError(error: error)
                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: nil, detailsViewController: nil)
                                    break
                                }
                                
                                vc.dialogService.showSuccess(withMessage: String.adamantLocalized.transfer.transferSuccess)
                                
                                guard let detailsVc = vc.router.get(scene: AdamantScene.Wallets.Doge.transactionDetails) as? DogeTransactionDetailsViewController else {
                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: nil)
                                    break
                                }
                                
                                detailsVc.transaction = transaction
                                detailsVc.service = service
                                detailsVc.senderName = String.adamantLocalized.transactionDetails.yourAddress
                                detailsVc.recipientName = self?.recipientName
                                
                                if comments.count > 0 {
                                    detailsVc.comment = comments
                                }
                                
                                vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: detailsVc)
                            }
                        }
                        
                    case .failure(let error):
                        vc.dialogService.showRichError(error: error)
                    }
                }
                
            case .failure(let error):
                dialogService.showRichError(error: error)
            }
        }
    }
    
    
    // MARK: Overrides
    
    private var _recipient: String?
    
    override var recipientAddress: String? {
        set {
            _recipient = newValue
            
            if let row: RowOf<String> = form.rowBy(tag: BaseRows.address.tag) {
                row.value = _recipient
                row.updateCell()
            }
        }
        get {
            return _recipient
        }
    }
    
    override func validateRecipient(_ address: String) -> Bool {
        guard let service = service else {
            return false
        }
        
        switch service.validate(address: address) {
        case .valid:
            return true
            
        case .invalid, .system:
            return false
        }
    }
    
    override func recipientRow() -> BaseRow {
        let row = TextRow() {
            $0.tag = BaseRows.address.tag
            $0.cell.textField.placeholder = String.adamantLocalized.newChat.addressPlaceholder
            
            if let recipient = recipientAddress {
                $0.value = recipient
            }
            
            if recipientIsReadonly {
                $0.disabled = true
                $0.cell.textField.isEnabled = false
            }
        }.onChange { [weak self] row in
            if let text = row.value {
                self?._recipient = text
            }
            
            if let skip = self?.skipValueChange, skip {
                self?.skipValueChange = false
                return
            }
            
            self?.validateForm()
        }
        
        return row
    }
    
    override func handleRawAddress(_ address: String) -> Bool {
        guard let service = service else {
            return false
        }
        
        let parsedAddress: String
        if address.hasPrefix("doge:"), let firstIndex = address.firstIndex(of: ":") {
            let index = address.index(firstIndex, offsetBy: 1)
            parsedAddress = String(address[index...])
        } else {
            parsedAddress = address
        }
        
        switch service.validate(address: parsedAddress) {
        case .valid:
            if let row: RowOf<String> = form.rowBy(tag: BaseRows.address.tag) {
                row.value = parsedAddress
                row.updateCell()
            }
            
            return true
            
        default:
            return false
        }
    }
    
    func reportTransferTo(admAddress: String, amount: Decimal, comments: String, hash: String) {
        let payload = RichMessageTransfer(type: DogeWalletService.richMessageType, amount: amount, hash: hash, comments: comments)
        
        let message = AdamantMessage.richMessage(payload: payload)
        
        chatsProvider.sendMessage(message, recipientId: admAddress) { [weak self] result in
            if case .failure(let error) = result {
                self?.dialogService.showRichError(error: error)
            }
        }
    }
    
    override func defaultSceneTitle() -> String? {
        return String.adamantLocalized.sendDoge
    }
}
