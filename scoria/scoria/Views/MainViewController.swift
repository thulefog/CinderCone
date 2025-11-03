//
// Reference Apple Sample Code: Classifying Images with Vision and Core ML
// https://developer.apple.com/documentation/coreml/classifying-images-with-vision-and-core-ml
//
// Abstract:
// The view controller that selects an image and makes a prediction using Vision and Core ML.
//
// Model:
// https://developer.apple.com/machine-learning/models/
//
// License:
// Apache License Version 2.0, January 2004

import SwiftUI

struct PredictorView: View {
    @State private var input = "model"
    
    var body: some View {
        NavigationView {
            VStack {
                MainViewRepresentable( input: $input )
                    .navigationTitle("Classify")
                HStack {
                    Spacer( minLength: 10 )
                    Divider()
                    Button(action: {
                        print("Handling user request")
                        input = "test"
                    }) {
                        Label("Start", systemImage: "water.waves")
                    } // button
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        print("Handling user request")
                        input = "test"
                    }) {
                        Label("Stop", systemImage: "water.waves.slash")
                    } // button
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        print("Handling user request")
                        input = "test"
                    }) {
                        Label("Flush", systemImage: "toilet")
                    } // button
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)

                    Divider()

                    Spacer( minLength: 10 )
                }.frame(width: 500, height: 80)
                Spacer( minLength: 10 )
            } // vstack
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: {
                            // TODO: ....
                        }) {
                            Label("Step One", systemImage: "perspective")
                        } // button
                        Divider()
                        Button(action: {
                            // TODO: ....
                        }) {
                            Label("Step Two", systemImage: "perspective")
                        } // button
                        
                    } label: {
                        Label("toolbar", systemImage: "mountain.2")
                    }
                } // toolbaritem
            } // toolbar
        }
    }
}

struct MainViewRepresentable: UIViewControllerRepresentable {
    @Binding var input: String
    typealias UIViewControllerType = MainViewController // Wrapped UIViewController subclass

    func makeUIViewController(context: Context) -> UIViewControllerType {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        return storyboard.instantiateViewController(withIdentifier: "MainViewControllerID") as! MainViewRepresentable.UIViewControllerType
    }
    // NB: to enable mixture of SwiftUI wrapping UIKit based on a storyboard, the above replaces below:
    //     func makeUIViewController(context: Context) -> UIViewControllerType { return MainViewController() }
    
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update the UIViewController based on SwiftUI state if needed
        print("\(#function): Requested session state: \(input).")


        // uiViewController.input = ...
    }
}


import UIKit

class MainViewController: UIViewController {
    var firstRun = true

    /// A predictor instance that uses Vision and Core ML to generate prediction strings from a photo.
    let imagePredictor = ImageClassificationProvider()

    /// The largest number of predictions the main view controller displays the user.
    let predictionsToShow = 2

    // MARK: Main storyboard outlets
    @IBOutlet weak var startupPrompts: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var predictionLabel: UILabel!
}

extension MainViewController {
    // MARK: Main storyboard actions
    /// The method the storyboard calls when the user one-finger taps the screen.
    @IBAction func singleTap() {
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            present(photoPicker, animated: false)
            return
        }

        print("\(#function)")
        present(cameraPicker, animated: false)
    }

    /// The method the storyboard calls when the user two-finger taps the screen.
    @IBAction func doubleTap() {
        print("\(#function)")
        present(photoPicker, animated: false)
    }
}

extension MainViewController {
    // MARK: Main storyboard updates
    /// Updates the storyboard's image view.
    /// - Parameter image: An image.
    func updateImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }

    /// Updates the storyboard's prediction label.
    /// - Parameter message: A prediction or message string.
    /// - Tag: updatePredictionLabel
    func updatePredictionLabel(_ message: String) {
        DispatchQueue.main.async {
            self.predictionLabel.text = message
        }

        if firstRun {
            DispatchQueue.main.async {
                self.firstRun = false
                self.predictionLabel.superview?.isHidden = false
                self.startupPrompts.isHidden = true
            }
        }
    }
    /// Notifies the view controller when a user selects a photo in the camera picker or photo library picker.
    /// - Parameter photo: A photo from the camera or photo library.
    func userSelectedPhoto(_ photo: UIImage) {
        updateImage(photo)
        updatePredictionLabel("Making predictions for the photo...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.classifyImage(photo)
        }
    }

}

extension MainViewController {
    // MARK: Image prediction methods
    /// Sends a photo to the Image Predictor to get a prediction of its content.
    /// - Parameter image: A photo.
    private func classifyImage(_ image: UIImage) {
        do {
            try self.imagePredictor.makePredictions(for: image,
                                                    completionHandler: imagePredictionHandler)
        } catch {
            print("Vision was unable to make a prediction...\n\n\(error.localizedDescription)")
        }
    }

    /// The method the Image Predictor calls when its image classifier model generates a prediction.
    /// - Parameter predictions: An array of predictions.
    /// - Tag: imagePredictionHandler
    private func imagePredictionHandler(_ predictions: [ImageClassificationProvider.Prediction]?) {
        guard let predictions = predictions else {
            updatePredictionLabel("No predictions. (Check console log.)")
            return
        }

        let formattedPredictions = formatPredictions(predictions)

        let predictionString = formattedPredictions.joined(separator: "\n")
        updatePredictionLabel(predictionString)
    }

    /// Converts a prediction's observations into human-readable strings.
    /// - Parameter observations: The classification observations from a Vision request.
    /// - Tag: formatPredictions
    private func formatPredictions(_ predictions: [ImageClassificationProvider.Prediction]) -> [String] {
        // Vision sorts the classifications in descending confidence order.
        let topPredictions: [String] = predictions.prefix(predictionsToShow).map { prediction in
            var name = prediction.classification

            // For classifications with more than one name, keep the one before the first comma.
            if let firstComma = name.firstIndex(of: ",") {
                name = String(name.prefix(upTo: firstComma))
            }

            return "\(name) - \(prediction.confidencePercentage)%"
        }

        return topPredictions
    }
}


import PhotosUI

extension MainViewController: PHPickerViewControllerDelegate {
    /// Creates a controller that gives the user a view they can use to select a photo from the device's library.
    var photoPicker: PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = PHPickerFilter.images

        let photoPicker = PHPickerViewController(configuration: config)
        photoPicker.delegate = self

        return photoPicker
    }

    /// The delegate method UIKit calls when the user selects a photo from the library.
    /// - Parameters:
    ///   - picker: A picker controller the `photoPicker` property created.
    ///   - results: An array of results. The method presumes the first result contains a photo.
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: false)

        guard let result = results.first else {
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            if let error = error {
                print("Photo picker error: \(error)")
                return
            }

            guard let photo = object as? UIImage else {
                fatalError("The Photo Picker's image isn't a/n \(UIImage.self) instance.")
            }

            self.userSelectedPhoto(photo)
        }
    }
}

import UIKit

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    /// Creates a controller that gives the user a view they can use to take a photo with the device's camera.
    var cameraPicker: UIImagePickerController {
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = self
        cameraPicker.sourceType = .camera
        return cameraPicker
    }

    /// The delegate method UIKit calls when the user takes a photo with the camera.
    /// - Parameters:
    ///   - picker: A picker controller the `cameraPicker` property created.
    ///   - info: A dictionary that contains the photo.
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: false)

        // Always return the original image.
        guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] else {
            fatalError("Picker didn't have an original image.")
        }

        guard let photo = originalImage as? UIImage else {
            fatalError("The (Camera) Image Picker's image isn't a/n \(UIImage.self) instance.")
        }

        userSelectedPhoto(photo)
    }
}
