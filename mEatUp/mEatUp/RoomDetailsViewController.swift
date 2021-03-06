//
//  RoomDetailsViewController.swift
//  mEatUp
//
//  Created by Krzysztof Przybysz on 13/04/16.
//  Copyright © 2016 BLStream. All rights reserved.
//

import UIKit
import CloudKit

class RoomDetailsViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var placeTextField: UITextField!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var hourTextField: UITextField!
    @IBOutlet weak var limitSlider: UISlider!
    @IBOutlet weak var limitLabel: UILabel!
    @IBOutlet weak var privateSwitch: UISwitch!
    @IBOutlet weak var rightBarButton: UIBarButtonItem!
    @IBOutlet weak var limitText: UILabel!
    @IBOutlet weak var privateText: UILabel!
    @IBOutlet weak var topTextField: UITextField!
    @IBOutlet weak var topLabel: UILabel!
    
    var activeField: UITextField?
    var room: Room?
    var chosenRestaurant: Restaurant?
    let datePicker = MeatupDatePicker()
    let formatter = NSDateFormatter()
    let stringLengthLimit = 30
    
    let cloudKitHelper = CloudKitHelper()
    
    var viewPurpose: RoomDetailsPurpose?
    var userRecordID: CKRecordID?
    
    @IBAction func sliderValueChanged(sender: UISlider) {
        limitLabel.text = "\(Int(sender.value))"
    }
    
    @IBAction func placeTextFieldEditing(sender: UITextField) {
        performSegueWithIdentifier("ShowRestaurantListViewController", sender: nil)
    }
    
    @IBAction func dateTextFieldEditing(sender: UITextField) {
        datePicker.date = NSDate()
        datePicker.datePickerMode = .Date
        
        sender.inputAccessoryView = datePicker.toolBar()
        datePicker.doneButtonAction = { [weak self] date in
            self?.dateTextField.text = self?.formatter.stringFromDate(date, withFormat: "dd.MM.yyyy")
            self?.view.endEditing(true)
        }
        datePicker.cancelButtonAction = { [weak self] in
            self?.view.endEditing(true)
        }
        sender.inputView = datePicker
    }
    
    @IBAction func hourTextFieldEditing(sender: UITextField) {
        datePicker.datePickerMode = .Time
        
        sender.inputAccessoryView = datePicker.toolBar()
        datePicker.doneButtonAction = { [weak self] date in
            self?.hourTextField.text = self?.formatter.stringFromDate(date, withFormat: "H:mm")
            self?.view.endEditing(true)
        }
        datePicker.cancelButtonAction = { [weak self] in
            self?.view.endEditing(true)
        }
        sender.inputView = datePicker
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let navigationCtrl = segue.destinationViewController as? UINavigationController, let destination = navigationCtrl.topViewController as? RestaurantListViewController {
            destination.saveRestaurant = { [weak self] restaurant in
                self?.placeTextField.text = restaurant.name
                self?.chosenRestaurant = restaurant
            }
        }
    }
    
    func registerForKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillBeHidden), name: UIKeyboardWillHideNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWasShown), name: UIKeyboardDidShowNotification, object: nil)
    }
    
    func keyboardWasShown(aNotification: NSNotification) {
        let info = aNotification.userInfo
        
        if let keyboardSize = (info?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            let contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0)
            scrollView.contentInset = contentInsets
            scrollView.scrollIndicatorInsets = contentInsets
            
            var aRect = self.view.frame
            aRect.size.height -= keyboardSize.height
            if let activeFieldFrame = activeField?.frame {
                if CGRectContainsPoint(aRect, activeFieldFrame.origin) {
                    scrollView.scrollRectToVisible(activeFieldFrame, animated: true)
                }
            }
        }
    }
    
    func keyboardWillBeHidden(aNotification: NSNotification) {
        let contentInsets = UIEdgeInsetsZero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        determineViewPurpose()
        
        guard let viewPurpose = viewPurpose else {
            return
        }
        
        setupViewForPurpose(viewPurpose)
        
        limitLabel.text = "\(room?.maxCount ?? Int(limitSlider.minimumValue))"
        datePicker.locale = NSLocale(localeIdentifier: "PL")
        registerForKeyboardNotifications()
        self.navigationController?.navigationBar.translucent = false;
    }
    
    func determineViewPurpose() {
        if room == nil {
            viewPurpose = RoomDetailsPurpose.Create
        } else if room?.owner?.recordID == userRecordID && room?.didEnd == false {
            viewPurpose = RoomDetailsPurpose.Edit
        } else {
            viewPurpose = RoomDetailsPurpose.View
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func setupViewForPurpose(purpose: RoomDetailsPurpose) {
        switch purpose {
        case .Create:
            rightBarButton.title = RoomDetailsPurpose.Create.rawValue
            enableUserInteraction(true)
        case .Edit:
            if let room = room {
                configureWithRoom(room)
            }
            rightBarButton.title = RoomDetailsPurpose.Edit.rawValue
            enableUserInteraction(true)
        case .View:
            topLabel.text = "Owner"
            topTextField.placeholder = "Owner"
            if let room = room {
                configureWithRoom(room)
            }
            navigationItem.rightBarButtonItems?.removeAll()
            enableUserInteraction(false)
        }
    }
    
    func enableUserInteraction(bool: Bool) {
        topTextField.userInteractionEnabled = bool
        placeTextField.userInteractionEnabled = bool
        dateTextField.userInteractionEnabled = bool
        hourTextField.userInteractionEnabled = bool
        limitSlider.userInteractionEnabled = bool
        privateSwitch.userInteractionEnabled = bool
    }
    
    func configureWithRoom(room: Room) {
        title = "\(room.title ?? "Room")"
        
        guard let viewPurpose = viewPurpose else {
            return
        }
        
        if let name = room.owner?.name, let surname = room.owner?.surname, let date = room.date, let limit = room.maxCount, let access = room.accessType {

            switch viewPurpose {
            case .View:
                topTextField.text = "\(name) \(surname)"
            case .Edit:
                topTextField.text = room.title
            case .Create:
                break
            }
            
            if room.didEnd == true {
                privateSwitch.hidden = true
                limitSlider.hidden = true
                limitText.hidden = true
                privateText.hidden = true
                limitLabel.hidden = true
            }
            
            placeTextField.text = room.restaurant?.name
            hourTextField.text = formatter.stringFromDate(date, withFormat: "H:mm")
            dateTextField.text = formatter.stringFromDate(date, withFormat: "dd.MM.yyyy")
            limitSlider.value = Float(limit)
            privateSwitch.on = access == AccessType.Private ? true : false
        }
    }
    
    func textFieldsAreFilled() -> Bool {
        guard let topText = topTextField.text, placeText = placeTextField.text, dateText = dateTextField.text, hourText = hourTextField.text else {
            return false
        }
        
        if !topText.isEmpty && !placeText.isEmpty && !dateText.isEmpty && !hourText.isEmpty {
            return true
        }
        
        return false
    }
    
    func createRoom() {
        rightBarButton.enabled = false
        room = Room()
        room?.owner?.recordID = userRecordID
        room?.maxCount = Int(limitSlider.value)
        room?.accessType = AccessType(rawValue: privateSwitch.on ? AccessType.Private.rawValue : AccessType.Public.rawValue)
        room?.title = topTextField.text
        if let day = dateTextField.text, hour = hourTextField.text {
            room?.date = formatter.dateFromString(day, hour: hour)
        }
        if let restaurant = chosenRestaurant {
            room?.restaurant = restaurant
        }
        
        if let room = room where textFieldsAreFilled() {
            cloudKitHelper.saveRoomRecord(room, completionHandler: {
                if let userRecordID = self.userRecordID, let roomRecordID = room.recordID {
                    let userInRoom = UserInRoom(userRecordID: userRecordID, roomRecordID: roomRecordID, confirmationStatus: ConfirmationStatus.Accepted)
                    self.cloudKitHelper.saveUserInRoomRecord(userInRoom, completionHandler: {
                        self.navigationController?.popViewControllerAnimated(true)
                    }, errorHandler: nil)
                }
            }, errorHandler: nil)
        } else {
            rightBarButton.enabled = true
            AlertCreator.singleActionAlert("Error", message: "Please fill all text fields.", actionTitle: "OK", actionHandler: nil)
        }
    }
    
    func updateRoom(room: Room) {
        room.title = topTextField.text
        room.restaurant?.name = placeTextField.text
        if let day = dateTextField.text, hour = hourTextField.text {
            room.date = formatter.dateFromString(day, hour: hour)
        }
        room.maxCount = Int(limitSlider.value)
        room.accessType = AccessType(rawValue: privateSwitch.on ? AccessType.Private.rawValue : AccessType.Public.rawValue)
        if let restaurant = chosenRestaurant {
            room.restaurant = restaurant
        }
        
        if textFieldsAreFilled() {
            cloudKitHelper.editRoomRecord(room, completionHandler: {
                self.navigationController?.popViewControllerAnimated(true)
            }, errorHandler: nil)
        } else {
            rightBarButton.enabled = true
            AlertCreator.singleActionAlert("Error", message: "Please fill all text fields.", actionTitle: "OK", actionHandler: nil)
        }
    }
    
    @IBAction func barButtonPressed(sender: UIBarButtonItem) {
        sender.enabled = false
        guard let viewPurpose = viewPurpose else {
            return
        }
        
        switch viewPurpose {
        case .Create:
            createRoom()
        case .Edit:
            if let room = room {
                updateRoom(room)
            }
        case .View:
            break
        }
    }
}

extension RoomDetailsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        if textField == hourTextField || textField == dateTextField || textField == placeTextField {
            return false
        }
        return true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        activeField = textField
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        activeField = nil
    }
}
