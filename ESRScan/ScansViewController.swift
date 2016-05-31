//
//  Scans view controller
//
//  Copyright © 2015 Michael Weibel. All rights reserved.
//  License: MIT
//

import UIKit

class ScansViewController: UIViewController, UITextViewDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var topToolbar: UIToolbar!
    // handling of tableView within extension TableView.swift
    @IBOutlet var tableView: UITableView!
    
    let textCellIdentifier = "TextCell"

    var activityIndicator: ActivityIndicator?
    var scans = Scans()
    var disco : Discover?

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        trackView("ScansViewController")
        self.disco = Discover.sharedInstance

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ScansViewController.connectionEstablished(_:)), name: "AppConnectionEstablished", object: nil)
        disco = Discover.sharedInstance
        disco?.startSearch()

        if self.disco?.connection != nil {
            self.navigationItem.rightBarButtonItem = nil
        }
        if scans.count() == 0 {
            self.navigationItem.leftBarButtonItem?.enabled = false
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView?.delegate = self
        self.tableView?.dataSource = self
    }

    func connectionEstablished(notification : NSNotification) {
        trackEvent("Connection", action: "Established", label: nil, value: nil)
        // send connection info to the app
        var dict = [String : AnyObject]()
        dict["name"] = UIDevice.currentDevice().name
        disco?.connection?.sendConnectionInfo(dict)

        self.navigationItem.rightBarButtonItem = nil

        // don't show modal if some other modal (e.g. image picker control) is visible
        let isModalVisible = self.presentedViewController != nil
        if !isModalVisible {
            performSegueWithIdentifier("displayConnectionInfo", sender: self)
            performSelector(#selector(ScansViewController.hideConnectionInfoModal), withObject: self, afterDelay: 1.5)
        }

        scans.scans.forEach({ scan in
            if !scan.transmitted {
                sendScan(scan, completion: {
                    // Suboptimal probably because it will reloadData on every sent scan
                    // but I assume this doesn't happen too often, so it's ok for now.
                    self.tableView.reloadData()
                })
            }
        })
    }

    func hideConnectionInfoModal() {
        dismissViewControllerAnimated(true, completion: nil)
    }

    func sendScan(scan: ESR, completion: (Void -> Void)?) {
        self.disco?.connection?.sendScan(scan.dictionary(), callback: { status in
            if status == true {
                trackEvent("Scan", action: "ESR transmitted", label: nil, value: nil)
                scan.transmitted = true
                completion?()
            }
        })
    }

    func performImageRecognition(rawImage: UIImage, autoCrop: Bool = true) {
        trackEvent("Scan", action: "Image captured", label: nil, value: nil)
        let startTime = NSDate.timeIntervalSinceReferenceDate()

        let image = preprocessImage(rawImage, autoCrop: false)
        
        let ocr = OCR.init()
        ocr.recognise(image)

        let endTime = NSDate.timeIntervalSinceReferenceDate()
        trackTiming("Scan", name: "Processing time", interval: endTime - startTime)

        let text = ocr.recognisedText()
        let textLines = text.componentsSeparatedByString("\n")
        let possibleCodes = textLines.filter{
            // make sure only valid strings in the array go in.
            $0.containsString(">") && $0.characters.count >= 32 && $0.characters.count <= 53 &&
            ESR.isValidTypeCode($0)
        }
        trackEvent("Scan", action: "Possible ESR Codes", label: nil, value: possibleCodes.count)
        if possibleCodes.count > 0 {
            let esrCode = possibleCodes[possibleCodes.count-1]
            do {
                let scan = try ESR.parseText(esrCode)
                self.scans.addScan(scan)
                self.navigationItem.leftBarButtonItem?.enabled = true
                self.tableView!.reloadData()

                if !scan.amountCheckDigitValid() {
                    trackEvent("Scan", action: "Parse success", label: "Parse error: amount", value: nil)
                }
                if !scan.refNumCheckDigitValid() {
                    trackEvent("Scan", action: "Parse success", label: "Parse error: refNum", value: nil)
                }
                if scan.amountCheckDigitValid() && scan.refNumCheckDigitValid() {
                    trackEvent("Scan", action: "Parse success", label: "No error", value: nil)
                }

                sendScan(scan, completion: {
                    self.tableView.reloadData()
                })
            } catch ESRError.AngleNotFound {
                trackCaughtException("AngleNotFound in string '\(esrCode)'")
                retryOrShowAlert(rawImage, autoCrop: autoCrop,
                    title: NSLocalizedString("Scan failed", comment: "Scan failed title in alert view"),
                    message: NSLocalizedString("Error scanning ESR code, please try again", comment: "Error message")
                )
            } catch let error {
                trackCaughtException("Error scanning ESR Code in string '\(esrCode)': \(error)")
                retryOrShowAlert(rawImage, autoCrop: autoCrop,
                    title: NSLocalizedString("Scan failed", comment: "Scan failed title in alert view"),
                    message: NSLocalizedString("Error scanning ESR code, please try again", comment: "Error message")
                )
            }
        } else {
            trackCaughtException("Error finding ESR Code on picture with width '\(rawImage.size.width)' and height '\(rawImage.size.height)'. Possible text lines: '\(textLines.count)'")
            retryOrShowAlert(rawImage, autoCrop: autoCrop,
                title: NSLocalizedString("Scan failed", comment: "Scan failed title in alert view"),
                message: NSLocalizedString("Error finding ESR code on picture, please try again", comment: "Error message")
            )
        }

        activityIndicator?.hide()
    }

    func retryOrShowAlert(rawImage: UIImage, autoCrop: Bool, title: String, message: String) {
        if autoCrop {
            return performImageRecognition(rawImage, autoCrop: false)
        }
        return showAlert(title, message: message)
    }

    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let actionOk = UIAlertAction(
            title: NSLocalizedString("OK", comment: "OK Button on alert view"),
            style: .Default,
            handler: nil
        )
        alertController.addAction(actionOk)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    @IBAction func takePhoto(sender: AnyObject) {
        let imagePickerActionSheet = UIAlertController(title: NSLocalizedString("Snap/Use Photo", comment: "Title for menu which appears when clicking the camera button."),
            message: nil, preferredStyle: .ActionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            let cameraButton = UIAlertAction(title: NSLocalizedString("Take Photo", comment: "Menu-item title for taking a photo using the camera."),
                style: .Default) { (alert) -> Void in
                    let imagePicker = UIImagePickerController()
                    imagePicker.delegate = self
                    imagePicker.sourceType = .Camera
                    self.presentViewController(imagePicker,
                        animated: true,
                        completion: nil)
            }
            imagePickerActionSheet.addAction(cameraButton)
        }

        let libraryButton = UIAlertAction(title: NSLocalizedString("Choose existing", comment: "Menu-item title for choosing an existing photo from the library."),
            style: .Default) { (alert) -> Void in
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .PhotoLibrary
                self.presentViewController(imagePicker,
                    animated: true,
                    completion: nil)
        }
        imagePickerActionSheet.addAction(libraryButton)

        let cancelButton = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"),
            style: .Cancel) { (alert) -> Void in
        }
        imagePickerActionSheet.addAction(cancelButton)
        
        presentViewController(imagePickerActionSheet, animated: true,
            completion: nil)
    }

    @IBAction func clearTextView(sender: AnyObject) {
        let alertCtrl = UIAlertController.init(
            title: NSLocalizedString("Clear scans", comment: "Button for clearing the scanned items"),
            message: NSLocalizedString("Are you sure you want to remove the scans?", comment:"Message if its ok to clear the scans"),
            preferredStyle: UIAlertControllerStyle.Alert
        )
        alertCtrl.addAction(UIAlertAction(
            title: NSLocalizedString("Yes", comment: "Button for confirming that clearing the scans is ok."),
            style: .Default,
            handler: {
                (action: UIAlertAction!) in
                    self.scans.clear()
                    self.tableView!.reloadData()
                    self.navigationItem.leftBarButtonItem?.enabled = false
            }
        ))

        alertCtrl.addAction(UIAlertAction(
            title: NSLocalizedString("No", comment: "No button"),
            style: .Default,
            handler: nil
        ))

        presentViewController(alertCtrl, animated: true, completion: nil)
    }

    @IBAction func shareTextView(sender: AnyObject) {
        trackEvent("Share Button", action: "Click", label: nil, value: nil)
        let activtyCtrl = UIActivityViewController.init(activityItems: [self.scans.string()], applicationActivities: nil)
        self.presentViewController(activtyCtrl, animated: true, completion: nil)
    }
}
