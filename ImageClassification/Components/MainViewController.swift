//
//  MainViewController.swift
//  ImageClassification
//
//  Created by Skafos.ai on 12/17/18.
//  Copyright © 2018 Metis Machine, LLC. All rights reserved.
//

import Foundation
import UIKit
import Skafos
import CoreML
import Vision
import SnapKit

class MainViewController : ViewController {
  // This will be the asset name you use in drag and drop on the dashboard
  private let assetName:String                  = "ImageClassifier"
  private let imageClassifier:ImageClassifier!  = ImageClassifier()
  private var currentImage:UIImage!             = nil

  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.photoButton.addTarget(self, action: #selector(photoAction(_:)), for: .touchUpInside)
    self.cameraButton.addTarget(self, action: #selector(cameraAction(_:)), for: .touchUpInside)

    // Skafos load cached asset
    // If you pass in a tag, Skafos will make a network request to fetch the asset with that tag
    Skafos.load(asset: assetName, tag: "latest") { (error, asset) in
      // Log the asset in the console
      console.info(asset)
      guard error == nil else {
        console.error("Skafos load asset error: \(String(describing: error))")
        return
      }
      guard let model = asset.model else {
        console.info("No model available in the asset")
        return
      }
      // Assign model to the imageClassifier class
      self.imageClassifier.model = model
    }
    /***
      Listen for changes in an asset with the given name. A notification is triggered anytime an
      asset is downloaded from the servers. This can happen in response to a push notification
      or when you manually call Skafos.load with a tag like above.
     ***/
    NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.reloadModel(_:)), name: Skafos.Notifications.assetUpdateNotification(assetName), object: nil)
  }

  @objc func reloadModel(_ notification:Notification) {
    Skafos.load(asset: assetName) { (error, asset) in
      console.info(asset)
      guard error == nil else {
        console.error("Skafos reload asset error: \(String(describing: error))")
        return
      }
      guard let model = asset.model else {
        console.error("No model available in the asset")
        return
      }
      // Assign model to the imageClassifier class
      self.imageClassifier.model = model
    }
  }
    
  @objc
  func cameraAction(_ sender:Any? = nil) {
    let myPickerController = UIImagePickerController()
    myPickerController.delegate = self;
    myPickerController.sourceType = .camera
    self.present(myPickerController, animated: true, completion: nil)
  }

  @objc
  func photoAction(_ sender:Any? = nil) {
    let myPickerController = UIImagePickerController()
    myPickerController.delegate = self;
    myPickerController.sourceType = .photoLibrary
    self.present(myPickerController, animated: true, completion: nil)
  }

  func classifyImage(image:UIImage) {
    self.currentImage = image
    let orientation   = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))!
    guard let ciImage = CIImage(image: image) else { fatalError("Bad image") }
    let model = try! VNCoreMLModel(for: self.imageClassifier.model)
    
    let request = VNCoreMLRequest(model: model) {[weak self] request, error in
      self?.processClassifications(for: request, error: error)
    }
    request.imageCropAndScaleOption = .centerCrop
    
    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      
      do {
        try handler.perform([request])
      } catch {
        print("Failed: \n\(error.localizedDescription)")
      }
    }
  }

  func showClassification(message:String) {
    let alertController = UIAlertController(title: "Classification", message: message, preferredStyle: .alert)
    let previewImage = self.currentImage.imageWithSize(scaledToSize: CGSize(width: 150, height: 150))
    let customView = UIImageView(image: previewImage)
    alertController.view.addSubview(customView)
    
    customView.snp.makeConstraints { make in
      make.top.equalToSuperview().offset(100)
      make.centerX.equalToSuperview()
      make.height.equalTo(previewImage.size.height)
    }
    
    alertController.view.snp.makeConstraints { (make) in
      make.height.equalTo(customView.frame.height+190)
    }
    
    let action = UIAlertAction(title: "OK", style: .default) { (actionitem) in
      if let imagePicker = (self.presentedViewController as? UIImagePickerController) {
        if (imagePicker.sourceType == .camera) {
          self.dismiss(animated: false, completion: nil)
        }
      }
    }
    
    alertController.addAction(action)
    
    // Save to Photo Library
    if let imagePicker = (self.presentedViewController as? UIImagePickerController) {
      if (imagePicker.sourceType == .camera) {
        let saveAction = UIAlertAction(title: "Save Image", style: .default) { (actionitem) in
          UIImageWriteToSavedPhotosAlbum(self.currentImage, nil, nil, nil)
          self.dismiss(animated: false, completion: nil)
        }
        alertController.addAction(saveAction)
      }
    }

    self.presentedViewController?.present(alertController, animated: true, completion: nil)
  }
  
  func processClassifications(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      guard let results = request.results else {
        print("Unable to classify image.\n\(error!.localizedDescription)")
        return
      }
      // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
      let classifications = results as! [VNClassificationObservation]
      
      if classifications.isEmpty {
        print("No Classifications")
      } else {
        // Display top classifications ranked by confidence in the UI.
        let topClassifications = classifications.prefix(2)
        let descriptions = topClassifications.map { classification in
          // Formats the classification for display; e.g. "(0.375) cliff, drop, drop-off".
          return String(format: "  (%.3f) %@", classification.confidence, classification.identifier)
        }

        let message = descriptions.joined(separator: "\n")
        self.showClassification(message: message)
      }
    }
  }
}

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    self.dismiss(animated: true, completion: nil)
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
      self.classifyImage(image: image)
    }else{
      print("Something went wrong")
      self.dismiss(animated: true, completion: nil)
    }
  }
}
