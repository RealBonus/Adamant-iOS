//
//  AdamantChatsProvider+search.swift
//  Adamant
//
//  Created by Anton Boyarkin on 11/12/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import CoreData

extension AdamantChatsProvider {
    func getMessages(containing text: String, in chatroom: Chatroom?) -> [MessageTransaction]?
    {
        let request = NSFetchRequest<MessageTransaction>(entityName: "MessageTransaction")
        
        if let chatroom = chatroom {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "chatroom == %@", chatroom),
                NSPredicate(format: "message CONTAINS[cd] %@", text),
                NSPredicate(format: "chatroom.isHidden == false"),
                NSPredicate(format: "isHidden == false")])
        } else {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "message CONTAINS[cd] %@", text),
                NSPredicate(format: "chatroom.isHidden == false"),
                NSPredicate(format: "isHidden == false")])
        }
        
        
        request.sortDescriptors = [NSSortDescriptor.init(key: "date", ascending: false),
                                   NSSortDescriptor(key: "transactionId", ascending: false)]
        
        do {
            let results = try stack.container.viewContext.fetch(request)
            return results
        } catch let error{
            print(error)
        }
        
        return nil
    }
}
