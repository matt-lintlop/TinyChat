    //
    //  TinyChatViewController.swift
    //  TinyChat
    //
    //  Created by Matthew Lintlop on 12/6/17.
    //  Copyright © 2017 Matthew Lintlop. All rights reserved.
    //

    import UIKit

    class TinyChatRoomViewController: UIViewController, UITextFieldDelegate, TinyChatRoomDelegateProtocol {
        
        @IBOutlet weak var messagesTextView: UITextView!
        @IBOutlet weak var messageTextField: UITextField!
        @IBOutlet weak var messageLabelBottomConstraint: NSLayoutConstraint!
        @IBOutlet weak var messageLabelRightConstraint: NSLayoutConstraint!
        @IBOutlet weak var sendButton: UIButton!
        
        var chatRoom: TinyChatRoom!
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            chatRoom = TinyChatRoom()
            chatRoom.delegate = self
            chatRoom.setupNetworkCommunication()
            chatRoom.startCheckingReachability()
            if chatRoom.isChatServerReachable() {
                chatRoom.downloadMessagesSinceLastTimeConnected()
                chatRoom.sendOutgoingMessages()
           }
            
            NotificationCenter.default.addObserver(self, selector: #selector(TinyChatRoomViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(TinyChatRoomViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(TinyChatRoomViewController.handleTextFieldChanged(notification:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)

            enableSendButton()
     
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.chatRoom = chatRoom
        }
        
        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
            // Dispose of any resources that can be recreated.
        }
        
        @IBAction func sendPressed(_ sender: Any) {
            guard let text = messageTextField.text else {
                return
            }
            chatRoom.userDidEnterMessage(text)
            messageTextField.text = nil
            enableSendButton()
        }
        
        func enableSendButton() {
            var enabled = false
            if let text = messageTextField.text {
                if text.count >= 1 {
                    enabled = true
                }
            }
            sendButton.isEnabled = enabled
         }
        
        // show an alert when the user sends a message offline
        func showOfflineMessageSentAlert() {
            let alertController = UIAlertController(title: "No Internet", message:
                "Your message will be sent when you are back online.", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default,handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }

        // MARK: Notifications
        
        @objc func keyboardWillShow(notification: NSNotification) {
            guard let keyboardSize = ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey]) as? NSValue)?.cgRectValue else {
                return
            }
            
            UIView.animate(withDuration: 0.5) {
                self.messageLabelBottomConstraint.constant = keyboardSize.size.height + 10
                self.messageLabelRightConstraint.constant = CGFloat(16)
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
            
        }
        
        @objc func keyboardWillHide(notification: NSNotification) {
            UIView.animate(withDuration: 0.5) {
                self.messageLabelBottomConstraint.constant = 10
                self.messageLabelRightConstraint.constant = CGFloat(90)
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }
        
        @objc func handleTextFieldChanged(notification: NSNotification) {
            enableSendButton()
        }

        // MARK: ChatRoomDelegateProtocol
        
        func showMessage(_ message: String) {
            guard message.count > 0 else {
                return
            }
            if Thread.current.isMainThread {
                messagesTextView.text.append("\(message)\r")
            }
            else {
                DispatchQueue.main.async(execute: {
                    self.messagesTextView.text.append("\(message)\r")
                })
            }
        }
        
        // MARK: UITextFieldDelegate
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // hide the keyboard when Return pressed
            textField.resignFirstResponder()
            return true
        }
    }
