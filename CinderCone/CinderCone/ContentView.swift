//
//  ContentView.swift
//  CinderCone
//
//  Created by John Matthew Weston on 9/1/25.
//
import SwiftUI
import UIKit

import AVKit

struct WorklistTaskItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

struct WorklistView: View {
    @State private var presentAlert = false
    
    @State private var newListItem: String = ""
    
    @State private var worklistTasks = [
        WorklistTaskItem(title: "Open Image Capture Device"),
        WorklistTaskItem(title: "Capture Image Frame Sequence"),
        WorklistTaskItem(title: "Post Process Image Frames on lcoal GPU using Metal shaders"),
        WorklistTaskItem(title: "Display Image Frames using Metal texture"),
        WorklistTaskItem(title: "Store Image Frames to remote image sink store"),
        WorklistTaskItem(title: "Post Process Image Frames on remote GPU cores using CUDA"),
        WorklistTaskItem(title: "Review Image Data Pipeline Results")
    ]

    let columns = [GridItem(.flexible())]
    
    var body: some View {
        Text("Worklist")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack {
            GroupBox(
                label: Label("Worklist Tasks", systemImage: "list.bullet.clipboard")
                    .foregroundColor(.orange)
            ) {
                Text("The current number of worklist tasks is: \(worklistTasks.count)")
            }.padding()
            List {
                ForEach(worklistTasks) { item in
                    Text(item.title)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
            HStack {
                /*... systemImage: "add.rectangle", ... */
                Button( "Add", action: {
                    presentAlert = true
                })
                .alert("Worklist Element", isPresented: $presentAlert, actions: {
                    TextField("Task", text: $newListItem)
                    Button("Add", action: {
                        worklistTasks.append(WorklistTaskItem(title: newListItem))
                    })
                    Button("Cancel", role: .cancel, action: {})
                }, message: {
                    Text("Please enter the task description.")
                })

                EditButton()
            }.padding()
                .navigationTitle("Cinder Cone")
            Spacer( minLength: 10 )
        }
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
    
    func deleteItems(at offsets: IndexSet) {
        worklistTasks.remove(atOffsets: offsets)
    }
    
    func moveItems(fromIndex: IndexSet, newIndex: Int) {
        worklistTasks.move(fromOffsets: fromIndex, toOffset: newIndex)
    }
}

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
            
            /* -----
             // MARK: Filter - opencv2
            NavigationView {
                ImageFilterView()
                    .navigationTitle("Filter")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Filter", systemImage: "camera.filters")
            }
            ----- */
            
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
            
            /*
            // MARK: Predictor
            NavigationView {
                PredictorView()
                    .navigationTitle("Predictor")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Predictor", systemImage: "lizard.circle")
            }
             */

            SettingsTab()
                .tabItem {
                    Image(systemName: "gearshape.2")
                    Text("Settings")
                }
        }.preferredColorScheme(.dark)
            .tint(.orange)
            .onAppear(perform: {
                UITabBar.appearance().unselectedItemTintColor = .systemGray
                UITabBarItem.appearance().badgeColor = .systemOrange
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

