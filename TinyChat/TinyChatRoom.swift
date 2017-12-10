//
//  TinyChatRoom.swift
//  TinyChat
//
//  Created by Matthew Lintlop on 12/6/17.
//  Copyright © 2017 Matthew Lintlop. All rights reserved.
//

import Foundation
import UIKit

protocol TinyChatRoomDelegateProtocol {
    func showMessage(_ message: String);                        // Show A Message To The User
    func showOfflineMessageSentAlert();                         // Show Alert When User Sends Message Offfline
}

class TinyChatRoom : NSObject, TinyChatClientDelegate {
    var delegate: TinyChatRoomDelegateProtocol?                 // Chat Room Delegate
    var chatServerReachability: Reachability                    // Chat Server Reachability
    var outgoingMessages: [Message]?                            // Outgoing Messages
    var lastTimeConnected: Int?                                 // Time Of Last Connection To The Chat Server
    var chatServerReachableTimer: Timer?                        // Timer Used To Check For Reachability To Chat Server
    var chatClient: TinyChatClient?                             // Chat Client
    var jsonFromChatServer: String                              // Current JSON From Chat Server

    let chatServerIP = "52.91.109.76"                           // Chat Server IP Address
    let chatServerPort: UInt32 = 1234                           // Chat Server Port
    let outgoingMessagesDataFileName = "OutgoingMessages.json"  // Outgoing Message Data File
    let maxReadLength = 1024*4                                  // Maximum # Of Bytes Read From Chat Server

    override init() {
        self.delegate = nil
        self.chatServerReachability = Reachability(hostName: chatServerIP)
        self.chatClient = TinyChatClient()
        self.jsonFromChatServer = ""
        
        super.init()

        self.chatClient?.delegate = self

        // load outgoing messages that are persisted on disk
        self.loadOutgoingMessages()
    
        // start periodic tasks
        resume()
    }
    
    deinit {
        self.chatServerReachability.stopNotifier()
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupNetworkCommunication() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        chatClient?.connectToChatServer ()
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

    func teardownNetworkCommunication() {
        chatClient?.disconnect()
    }
    
    func getLastTimeConnected() {
        let defaults = UserDefaults()
        let lastTime = defaults.integer(forKey: "lastTimeConnected")
        if lastTime == 0 {
            setLastTimeConnectedToNow()
        }
        else {
            self.lastTimeConnected = lastTime
        }
    }
    
    func setLastTimeConnectedToNow() {
        let defaults = UserDefaults()
        let time = currentTime()
        defaults.set(time, forKey: "lastTimeConnected")
    }
    
    // Parse JSON from the server 1 object at a time
    func parseJSONFromServer(_ json: String) {
        
//        print("*****************************************************")
//        print("JSON From Server = \(json)")
//        print("*****************************************************")

        let formattedJSON = json.replacingOccurrences(of: "'", with: "\"")
        var index = 0;
        for char in formattedJSON {
            index += 1;
            if char == "\n" {
                continue
            }
            jsonFromChatServer += String(char)
            if char == "}" {
                do {
                    let data = jsonFromChatServer.data(using: .utf8)
                    let message = try JSONDecoder().decode(Message.self, from: data!)
                    delegate?.showMessage(message.msg)
//                    print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
//                    print("Success Parsing Message JSON: JSON = \(jsonFromChatServer)")
             }
                catch {
//                    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
//                    print("Error Parsing Message JSON: JSON = \(jsonFromChatServer)")
//                    print("Error Parsing Message JSON: ERROR = \(error.localizedDescription)")
                }
                jsonFromChatServer = ""
            }
        }
    }
 
    // MARK: Chat Server Reachability
    func startCheckingReachability() {
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: NSNotification.Name.reachabilityChanged, object: nil)
        self.chatServerReachability.startNotifier()
   }
    
    func isChatServerReachable() -> Bool {
        var reachable = false
        switch chatServerReachability.currentReachabilityStatus() {
            case ReachableViaWiFi,ReachableViaWWAN:
                reachable = true
            case NotReachable:
                reachable = false
            default:
                reachable = false
        }
        return reachable
    }
    
    @objc func reachabilityChanged(_ notification: NSNotification) {
        let reachable = isChatServerReachable()
        chatClient?.connected = reachable
        
        if reachable {
            downloadMessagesSinceLastTimeConnected();     // download all messages since last time connected
            sendOutgoingMessages()                        // send outgoing messages currently persisted to disk
       }
    }
    
    // MARK: Sending Messages
    func userDidEnterMessage(_ text: String) {
        // create a new Message with the given text at the current time
        let newMessage = Message(msg: text, client_time: currentTime())

        if isChatServerReachable() {
            // the chat server is reachable. send the messag
            _ = sendMessage(newMessage)
        }
        else {
            // the chat server is not reachable. add the message to outgoing messages.
            addOutgoingMessage(newMessage)
            
            // show alert to the user taht says the message was not sent.
            delegate?.showOfflineMessageSentAlert()
        }
    }
    
    // download messages from the chat server after a given date
    func downloadMessagesSinceDate(_ since: Int) -> Bool {
        guard self.chatClient != nil && self.chatClient!.connected else {
            return false
        }
        var result = true
        let encoder = JSONEncoder()
        do {
            let history = History(since: since)
            var data = try encoder.encode(history)
            return chatClient!.write(data, length: UInt(data.count))
        } catch {
            print("Error Getting History: \(error.localizedDescription)")
            result = false
        }
        return result
    }
  
    // send a message to the chat server
    func sendMessage(_ message: Message) -> Bool {
        let encoder = JSONEncoder()
        do {
            print("Now Sending Message: \(message.msg)")
           let data = try encoder.encode(message)
            return chatClient!.write(data, length: UInt(data.count))
        } catch {
            print("Error Sending Message: \(error.localizedDescription)")
        }
        return true
    }

    // MARK: Outgoing Messages
    
    // Load all outgoing messages
    func loadOutgoingMessages() {
        guard let url = getOutgoingMessagesURL() else  {
            return
        }
        let decoder = JSONDecoder()
        do {
            let data = try Data(contentsOf: url, options: [])
            self.outgoingMessages = try decoder.decode([Message].self, from: data)
        } catch {
            // ignore the error
        }
    }
    
    // Save all outgoing messages tto the local disk.
    func saveOutgoingMessages() {
        guard let outgoingMessages = outgoingMessages else {
            return
        }
        guard outgoingMessages.count > 0 else {
            return
        }
        guard let url = getOutgoingMessagesURL() else {
            return
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(outgoingMessages)
            try data.write(to: url, options: [])
        } catch {
            print("Error Saving Outgoing Messages!: \(error.localizedDescription)")
        }
    }
    
    // Send all outgoing messages
    func sendOutgoingMessages() {
        guard let outgoingMessages = outgoingMessages else {
            return
        }
        guard outgoingMessages.count > 0 else {
            return
        }
        var sentMessageCount = 0;
        var failedMessageCount = 0;

        print("Now Sending: \(outgoingMessages.count) Messages")

        DispatchQueue.global(qos: .background).async {
            var failedMessages: [Message] = []
            
            
            
            
            for message in outgoingMessages {
                if (!self.sendMessage(message)) {
                    print("FAILED Sending Message: \(message.msg)")
                    failedMessages.append(message)
                    failedMessageCount += 1
                }
                else {
                    print("SUCCESS! Sending Message: \(message.msg)")
                    sentMessageCount += 1
                }
            }
            self.outgoingMessages = failedMessages
            if failedMessages.count > 0 {
                self.saveOutgoingMessages()
            }
            else {
                self.deleteOutgoingMessages()
            }
         }
    }
    
    // Add a new outgoing mesage
    func addOutgoingMessage(_ message: Message) {
        if outgoingMessages == nil {
            outgoingMessages = []
        }
        outgoingMessages?.append(message)
        saveOutgoingMessages()
    }
    
    // Delete all outgoing messages
    func deleteOutgoingMessages() {
        guard let url = getOutgoingMessagesURL() else {
            return
        }
        try? FileManager().removeItem(at: url)
    }
    
    // Get the url of the outgoing messages data file
    func getOutgoingMessagesURL() -> URL? {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docURL.appendingPathComponent(outgoingMessagesDataFileName)
    }
    
    func stopChatSession() {
        chatClient?.disconnect()
    }
    
    // MARK: TinyChatClientDelegate
    
    func processData(fromChatServer buffer: UnsafeMutablePointer<UInt8>!, length: Int32) {
        guard length > 0 else {
            return
        }
        let data = Data(bytes: buffer, count: Int(length))
        if let json = String(data: data, encoding: .utf8) {
            parseJSONFromServer(json)
        }
    }
    
    // MARK: Message History
    
    func downloadMessagesSinceLastTimeConnected() {
        getLastTimeConnected()
        guard let lastTimeConnected = lastTimeConnected else {
            return
        }
 
        if lastTimeConnected != 0 {
            let _ = downloadMessagesSinceDate(lastTimeConnected)
            setLastTimeConnectedToNow()
            return
        }
        else {
            return
        }
    }
    
    // MARK: Suspend & Resume
    
    // supend periodic chat room tasks
    func suspend() {
        chatClient?.suspend()
        chatServerReachableTimer?.invalidate()
        chatServerReachableTimer = nil
    }
    
    // resume periodic chat room tasks
    func resume() {
        chatClient?.resume()
        chatServerReachableTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(testChatServerReachability), userInfo: nil, repeats: true)
        chatServerReachableTimer?.fire()
    }

    @objc func testChatServerReachability() {
        if self.isChatServerReachable() {
            self.setLastTimeConnectedToNow()
        }
    }
}

