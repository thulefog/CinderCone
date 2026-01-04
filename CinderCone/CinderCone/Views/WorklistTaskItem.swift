//
//  WorklistView.swift
//  CinderCone
//
//  Created by John Matthew Weston on 1/4/26.
//
import SwiftUI

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
