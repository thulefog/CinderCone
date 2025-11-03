//
//  ViewController.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 24/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import UIKit
import Metal

internal final class CameraViewController: MTKViewController {
    var sessionInitialized: Bool = false //...
    var session: MetalCameraSession?
    var state: MetalCameraSessionState = .stopped {
        didSet {
            print("CameraViewController, didset, \(#function): *state: \(state)")
            
            switch state {
            case .stopped:

                print( "GUARD: first stop based on device state" )
                /*
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.session?.stop()
                }
                ..
                if sessionInitialized {
                    //session?.stop()
                    Task(priority: .background) {
                        session?.stop()
                    }
                }*/
                if sessionInitialized {
                    session?.stop()
                }
                
            case .streaming:
                session?.start()
                sessionInitialized = true
            default:
                break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
            session = MetalCameraSession(frameOrientation: .portrait, delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.session?.stop()
        }
    }
}

// MARK: - MetalCameraSessionDelegate
extension CameraViewController: MetalCameraSessionDelegate {
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
    }
    
    func metalCameraSession(_ cameraSession: MetalCameraSession, didUpdateState state: MetalCameraSessionState, error: MetalCameraSessionError?) {
        NSLog("\(#function): Requested session *state: \(state).")

        switch state {
            // not hit
        case .stopped:
            cameraSession.stop()
        case .streaming:
            cameraSession.start()
            
        case .error where error == .captureSessionRuntimeError:
            NSLog("\(#function): Requested session state \(state) with error: \(error?.localizedDescription ?? "None").")
            // Ignoring capture session runtime errors
            cameraSession.start()
        default:
            break
        }
        DispatchQueue.main.async {
            self.title = "Metal camera: \(state)"
        }
        NSLog("\(#function): Session changed state to \(state) with error: \(error?.localizedDescription ?? "None").")
    }
}
