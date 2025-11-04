# Scoria

Scoria is a reference to the proper name for lava rock or cinder and a Cinder Cone is a specific type of volcano formed when cinder fragments ejected from the volcano.

First, the points to fact that enabling the iPhone camera as a capture device and channeling to a Metal pipeline creates an explosion of pixel data, a volcano of sorts.

Second, the name is in honor of the the classic Cinder Cone mountain bike from Kona, an example actually in my garage as I type this.

## Abstract

The original context for the code behind the original rough concept proof dates back to workbench learning in 2018. 

This is a rewrite and modernization, leveraging code level lessons learned as well as changes and evolutions in the Apple frameworks and ecosystem.

Reference the breakdown of the workflow features summarized in the table below.

|Workflow|Description|
|--|--|
| Worklist | Editable list with workflow step summaries | 
| Capture | Camera based on `AVFoundation` with select Metal based texture shaders and frame capture  |
| Filter | Minimal image filter set based on OpenCV2 |
| Classifier | Minimal image classification based on the `MobileNet` model |
| Settings | Configuration area - examples would be Foundation Model selections |

For now, the `Worklist` view is simply a static recipe of steps to illustrate what the application does. 

This path could rough in results from fetched from a remote node, data from the REST endpoint - e.g. one based on Python and Flask.

* Capture

The camera device and session is opened and each static image frame is loaded into a Texture, passing through a Shader (compose style) and displayed in a Metal view. 

Note that the Metal view, which is UIKit, is actually hosted in a SwiftUI view, making use of the `UIViewControllerRepresentable` delegate and technique to bridge the two UI paradigms.

The seed Providers for the purposes of this rough concept proof were some of the prior work used as a reference point to ramp up on Metal in 2018.

* Filter

Currently an elevated feature but could shift be nested in a Classification or Segmentation workflow context.

* Classifier

Reference this code example which was uses `MobileNet` model
[Apple Sample Code: Classifying Images with Vision and Core ML](https://developer.apple.com/documentation/coreml/classifying-images-with-vision-and-core-ml)

No parts of this code sample were used but uses a diffent `Core ML Model`, `ObjectDetector`
[Apple Sample Code: Recognizing Objects in Live Capture](
https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture)

# References

[Apple: Core ML Models](https://developer.apple.com/machine-learning/models)

[Metal Programming Guide,  Janie Clayton, Addison-Wesley, 2017](https://www.safaribooksonline.com/library/view/metal-programming-guide/9780134668963/ch06.xhtml)

[Apple Developer: Metal sample code](https://developer.apple.com/search/?q=metal%20sample&type=Sample%20Code)


NOTE: 
- The original version sourced images from already acquired frame file sequence and texture shader to render as the intention was to illustrate riffing through an ultrasound image clip or movie. The code was shifted away to files and not use the device camera.
- Past work on `AVFoundation` realized a camera in iOS, but with a spin that the frames were displayed after being loaded into a Texture in a Shader in a Metal view.

Reference the `MetalRenderCamera` project code repository on Github which was an implementation of a Metal camera that also provided low friction access to the Texture to apply Shaders to.

 [SOUP: MetalRenderCamera](https://github.com/alexstaravoitau/MetalRenderCamera)

The open source project wired in has some collisions with known concurrency issues that were raised around `AVFoundation` and Swift 5 and 6. A recently published approach from Apple in the form of a ground up rewrite of a Metal based camera is URLd below. It requires iOS 26 and will be approached when I have an iPhone that has been upgraded to 26.

Reference this (new) Apple sample application that advertises to be a reinvention of the approach and from code walkthrough appears to bring things in line with latest Swift concurrency aspects.

[Apple Sample: AVFoundation, Metal Camera](https://developer.apple.com/documentation/AVFoundation/avcam-building-a-camera-app)

 See also below as a cross references:
 
 https://stackoverflow.com/questions/43838089/capture-metal-mtkview-as-movie-in-realtime/43860229#43860229
 https://developer.apple.com/metal/sample-code/
 
 
# Software License

Selected components of this project are a derivative of MetalRenderCamera, originally licensed under the Apache License, Version 2.0. This version includes additional modifications described herein. Portions of this code are reproduced under the terms of the Apache License, Version 2.0.


The original code was Apache 2.0 licensed. Changes in Swift around @objc inference called for slight local changes to the original code published on Github by the original author. Addditional adjustments surfaced that were needed due to the Swift 5.x to 6.x changes.
