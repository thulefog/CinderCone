//
//  ContentView.swift
//  scoria
//
//  Created by John Matthew Weston on 9/1/25.
//
import SwiftUI
import UIKit

//..
import AVKit
import CoreImage
import CoreImage.CIFilterBuiltins

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
            
            //  CaptureTab Embedded
            CaptureTab()
                .tabItem {
                    Image(systemName: "film.stack")
                    Text("Capture")
                }
            NavigationView {
                ImageFilterView()
                    .navigationTitle("Filter")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Filter", systemImage: "camera.filters")
            }
            NavigationView {
                PredictorView()
                    .navigationTitle("Predictor")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Classifier", systemImage: "lizard.circle")
            }

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

// MARK: - First Tab (SwiftUI)
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

struct SpeedometerGaugeStyle: GaugeStyle {
    private var purpleGradient = LinearGradient(gradient: Gradient(colors: [ .black,.gray,.white ]),
                                                startPoint: .trailing, endPoint: .leading)

    func makeBody(configuration: Configuration) -> some View {
        ZStack {

            Circle()
                .foregroundColor(Color(.systemGray6))

            Circle()
                .trim(from: 0, to: 0.75 * configuration.value)
                .stroke(purpleGradient, lineWidth: 5)
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 10, lineCap: .butt, lineJoin: .round, dash: [1, 34], dashPhase: 0.0))
                .rotationEffect(.degrees(135))

            VStack {
                configuration.currentValueLabel
                    .font(.system(size: 12, weight: .thin, design: .rounded))
                    .foregroundColor(.gray)
                Text("Frame Rate [fps]")
                    .font(.system(.caption2, design: .rounded))
                    .bold()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

        }
        .frame(width: 68, height: 68)
    }
}

struct CustomGaugeView: View {

    @State private var currentSpeed = 140.0

    var body: some View {
        Gauge(value: currentSpeed, in: 0...200) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 50.0))
        } currentValueLabel: {
            Text("\(currentSpeed.formatted(.number))")

        }
        .gaugeStyle(SpeedometerGaugeStyle())

    }
}

struct CaptureTab: View {
    @State private var tabState = 1
    
    var body: some View {
        NavigationView {
            VStack {
                MetalViewRepresentable( state: $tabState )
                    .navigationTitle("Capture")
                //DecibelMeterView(decibelValue: 0)
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
                }.frame(width: 500, height: 80)
                Spacer( minLength: 10 )
            } // vstack
        }/*
         .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
                 Menu {
                     Button(action: {
                         // TODO
                     }) {
                         Label("About", systemImage: "info.circle")
                     }
                     
                 } label: {
                     Label("More", systemImage: "square.grid.3x3.square.badge.ellipsis")
                 }
             }
         } // toolbar
         */
    }
}

struct MetalViewRepresentable: UIViewControllerRepresentable {
    @Binding var state: Int
    typealias UIViewControllerType = CameraViewController // Wrapped UIViewController subclass

    func makeUIViewController(context: Context) -> UIViewControllerType {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update the UIViewController based on SwiftUI state if needed
        print("\(#function): Requested session state: \(state).")

        if state == 1 {
            uiViewController.state = .streaming
        } else if state == 0 {
            uiViewController.state = .stopped
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// TODO: REMOVE - deprecated

// MARK: - Example UIKit, Embedded
struct UIKitTab: View {
    var body: some View {
        NavigationView {
            UIKitViewRepresentable()
                .navigationTitle("UIKit Tab")
        }
    }
}

// MARK: - UIViewRepresentable for UIKit Integration
struct UIKitViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return CustomUIKitView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the view if needed
    }
}

// MARK: - Custom UIKit View
class CustomUIKitView: UIView {
    private let textLabel = UILabel()
    private let colorButton = UIButton(type: .system)
    private let slider = UISlider()
    private let colorView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Configure text label
        textLabel.text = "This is a UIKit View!"
        textLabel.font = UIFont.boldSystemFont(ofSize: 24)
        textLabel.textAlignment = .center
        textLabel.textColor = .systemBlue
        
        // Configure button
        colorButton.setTitle("Change Color", for: .normal)
        colorButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        colorButton.backgroundColor = .systemBlue
        colorButton.setTitleColor(.white, for: .normal)
        colorButton.layer.cornerRadius = 8
        colorButton.addTarget(self, action: #selector(changeColorTapped), for: .touchUpInside)
        
        // Configure slider
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0.5
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        // Configure color view
        colorView.backgroundColor = .systemBlue.withAlphaComponent(0.5)
        colorView.layer.cornerRadius = 12
        
        // Add subviews
        addSubview(textLabel)
        addSubview(colorButton)
        addSubview(slider)
        addSubview(colorView)
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupConstraints() {
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        colorView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Text label
            textLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            textLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 50),
            
            // Color view
            colorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorView.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 30),
            colorView.widthAnchor.constraint(equalToConstant: 200),
            colorView.heightAnchor.constraint(equalToConstant: 100),
            
            // Slider
            slider.centerXAnchor.constraint(equalTo: centerXAnchor),
            slider.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 30),
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            
            // Button
            colorButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 30),
            colorButton.widthAnchor.constraint(equalToConstant: 150),
            colorButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func changeColorTapped() {
        let colors: [UIColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple]
        let randomColor = colors.randomElement() ?? .systemBlue
        
        UIView.animate(withDuration: 0.3) {
            self.colorView.backgroundColor = randomColor.withAlphaComponent(CGFloat(self.slider.value))
            self.textLabel.textColor = randomColor
        }
    }
    
    @objc private func sliderValueChanged() {
        colorView.alpha = CGFloat(slider.value)
    }
}

