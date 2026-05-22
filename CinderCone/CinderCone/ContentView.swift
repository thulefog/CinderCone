//
//  ContentView.swift
//  CinderCone
//
//  Created by John Matthew Weston on 9/1/25.
//
import SwiftUI
import UIKit

import AVKit


// MARK: - Main Content View with Tab Navigation
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack() {
                WorklistView()
                    .navigationTitle("Cinder Cone")
            }
            .tabItem {
                Label("Worklist", systemImage: "list.bullet.clipboard")
            }
            
            // MARK: Capture / Filter - Metal

            // NOTE: CameraProcessingViewport and CameraMLView have common denominators, XOR contention for device with current code state
            NavigationView {
                CameraProcessingViewport()
                    .navigationTitle("Capture")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Capture", systemImage: "film.stack")
            }

            // MARK: Texture - Metal

            NavigationView {
                MetalTextureViewport()
                .navigationTitle("Texture")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Texture", systemImage: "lizard")
            }
            
            // MARK: Classifier
            
            // NOTE: functions with either YOLOv3 or MobileNetV2, one noticable difference of bounding box
            NavigationView {
                CameraMLView()
                    .navigationTitle("Classifier")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Classifier", systemImage: "tortoise.circle")
            }
            
            SettingsTab()
                .tabItem {
                    Image(systemName: "gearshape.2")
                    Text("Settings")
                }
        }.preferredColorScheme(.dark)
            .tint(coneAmber)
            .onAppear(perform: {
                UITabBar.appearance().unselectedItemTintColor = .systemGray
                UITabBarItem.appearance().badgeColor = UIColor(coneAmber)
            })
    }
}

// MARK: CaptureTab

struct CaptureTab: View {
    @State private var tabState = 1
    
    var body: some View {
        NavigationView {
            VStack {
                
                // DEPRECATE:
                
                // post iOS 26.x, remove dependency on open sourced code layers
                // part of target sfhit to "from scratch" Metal viewer and camera implementation
                // camera code behind has external open source dependency with observed start/stop rough edges
                //
                // MetalViewRepresentable > CameraViewController > MTKViewController > MetalCameraCaptureDevice > MetalCameraSession
                // MetalViewRepresentable( state: $tabState )
                //     .navigationTitle("Capture")
                
                // This iterations were spikes to explore options:
                // MetalTextureViewport, CameraProcessingViewport, CameraMLView

                HStack {
                    Spacer( minLength: 10 )
                    Divider()
                    Button(action: {
                        print("Handling user request")
                        tabState = 1
                        
                    }) {
                        Label("Start", systemImage: "water.waves")
                    } // button
                    .buttonStyle(.borderedProminent)
                    .disabled(tabState == 1 )
                    
                    Button(action: {
                        print("Handling user request")
                        tabState = 0
                    }) {
                        Label("Stop", systemImage: "water.waves.slash")
                    } // button
                    .buttonStyle(.borderedProminent)
                    .disabled(tabState == 0 )
                    
                    Button(action: {
                        print("User action: flush the frames in temporary files directory")
                        removeTemporaryFiles()
                    }) {
                        Label("Flush", systemImage: "toilet")
                    } // button
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    
                    Divider()
                    CustomGaugeView()
                    //GaugeView(coveredRadius: 250, maxValue: 200, stepperSplit: 10, value: $value )
                    
                    Spacer( minLength: 10 )
                    
                }.frame(width: 500, height: 80) //hstack
                Spacer( minLength: 10 )
                 
                
            } // vstack
        }// NOTE: toolbar intentionally removed to dedicate view space for camera  - revisit
    }
}


// MARK: - Settings Tab

struct SettingsTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // TODO: configuration settings...
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // TODO
                        }) {
                            Label("About", systemImage: "info.circle")
                        }
                        
                    } label: {
                        Label("toolbar", systemImage: "mountain.2.circle")
                    }
                }
            } // toolbar
            .padding()
            .navigationTitle("Cinder Cone")
        }
    }
}

func removeTemporaryFiles() {
    let fileManager = FileManager.default
    let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory())

    do {
        let tmpFiles = try fileManager.contentsOfDirectory(at: tmpDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        var removedCount = 0

        for url in tmpFiles {
            do {
                try fileManager.removeItem(at: url)
                removedCount += 1
            } catch {
                print("Error removing temporary file at \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        print("\(removedCount) temporary files removed.")
    } catch {
        print("Error accessing temporary directory: \(error.localizedDescription)")
    }
}


// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

