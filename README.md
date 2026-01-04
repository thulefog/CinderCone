# Cinder Cone

The term `Cinder Cone` is a specific type of volcano formed when cinder fragments ejected from the volcano.

First, the points to fact that enabling the iPhone camera as a capture device and channeling to a Metal pipeline creates an explosion of pixel data, a volcano of sorts.

Second, the name is in honor of the the classic Cinder Cone mountain bike from Kona, an example actually in my garage as I type this.

# Abstract

The original context for the code behind the original rough concept proof dates back to workbench learning in 2018. 

This is a rewrite and modernization, leveraging code level lessons learned as well as changes and evolutions in the Apple frameworks and ecosystem.

## Workflow Summary

Reference the breakdown of the workflow features summarized in the table below.

|Workflow|Description|
|--|--|
| Worklist | Editable list with workflow step summaries | 
| Capture  / Filter | Camera based on Metal with texture shaders and a streamlined processing pipeline  |
| Texture | Minimal image viewer using a `Metal` texture based canvas  |
| Classifier | Minimal image classification based on the `MobileNet` model |
| Settings | Configuration area - examples would be Foundation Model selections |

For now, the `Worklist` view is simply a static recipe of steps to illustrate what the application does. 

## User Interface

See below for the current works in progress implementation, an evolutionary iteration increment forward in the area of latest Swift concurrency.

| Cinder Cone | 
|--|
| <img src="/statics/cinder-summary.png" alt="select" width="256"> | 

# Software Blueprint

The rough blueprint for key areas in the iOS application system are as follows:

- Type System
- Providers
- Models
- Views

There are some areas with caution tape around called `Widgets` that provides early implemenations `from scratch` that are being proved out. As a side note - the Foundation Model choices settle (public domain or custom) and as a general design surface - there is a potential for select `Adapters` to surface. Typically, they reside behind `Providers` and help add abstraction.

## Implementation Notes

* Capture

The camera device and session is opened and each static image frame is loaded into a Texture, passing through a Shader (compose style) and displayed in a Metal view. 

Note that the Metal view, which is UIKit, is actually hosted in a SwiftUI view, making use of the `UIViewControllerRepresentable` delegate and technique to bridge the two UI paradigms.

* Filter

The initial concept proof caliber `Filter` pathway was realized based on `OpenCV2` but is being reworked from scratch as a `Metal` pipeline. Based on the seismic shift in the area of concurrency in the from Swift language from versions 5 to 6.x, it was an objective to remove some open source layers and shift to from scratch for complete control code level of the code paths.

* Classifier

There are relevant Foundational Models for Classification are being tested out largely just to exercise the pipeline for now. Reference the information on [Apple: Core ML Models](https://developer.apple.com/machine-learning/models)

Models worth calling out include `YOLOv3` and `MobileNetV2`. 

Elsewhere, for Segmentation - of note are [github: MedSAM2](https://github.com/bowang-lab/MedSAM2) / [hugging face: MedSA23](https://huggingface.co/wanglab/MedSAM2)

# References
See below for select areas of code or documentation used as guidance.

## Prior Work

NOTE: 
- The original version sourced images from already acquired frame file sequence and texture shader to render as the intention was to illustrate riffing through an ultrasound image clip or movie. The code was shifted away to files and not use the device camera.
- Past work on `AVFoundation` realized a camera in iOS, but with a spin that the frames were displayed after being loaded into a Texture in a Shader in a Metal view.

Reference external dependency or SOUP removed from the mix. The open source project code repository on Github [MetalRenderCamera](https://github.com/alexstaravoitau/MetalRenderCamera) proved useful since around 2017. That project  was a good Metal camera reference implementation and select layers reusable rouhgly verbatim. It also provided low friction example(s) of Texture handling Shaders as well. Evidence showed that it needed repair in the area of frame capture start and stop for an active `Metal` pipeline and had some collisions with known concurrency issues that were raised around `AVFoundation` and Swift 5 and 6. 

- [Apple Developer Sample Code: Metal samples](https://developer.apple.com/search/?q=metal%20sample&type=Sample%20Code)
- [Apple Sample Code: Classifying Images with Vision and Core ML](https://developer.apple.com/documentation/coreml/classifying-images-with-vision-and-core-ml)
- [Apple Sample Code: Recognizing Objects in Live Capture](https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture)
- [Apple Developer Sample: Building a Camera APP, avcam](https://developer.apple.com/documentation/AVFoundation/avcam-building-a-camera-app)

The `avcam` Apple sample application advertised to be a reinvention of the approach around `AVFoundation` and `Metal` to realize a camera capture pathway with better concurrency in theory post iOS 26.x. From code walkthrough it does appear to bring things in line with latest Swift concurrency aspects but would take some refactoring to shift to a `MTLTexture` paradigm and has some complexity to work out.

# Software License

Selected components of this project are a derivative of MetalRenderCamera, originally licensed under the Apache License, Version 2.0. This version includes additional modifications described herein. Portions of this code are reproduced under the terms of the Apache License, Version 2.0.

The original open source code used as a starting point was Apache 2.0 licensed. Changes in Swift around @objc inference called for slight local changes to the original code published on Github by the original author. Addditional adjustments surfaced that were needed due to the Swift 5.x to 6.x changes.

The rest of the source code is under the MIT License as per below:

MIT License

Copyright (c) 2025 John Matthew Weston

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
