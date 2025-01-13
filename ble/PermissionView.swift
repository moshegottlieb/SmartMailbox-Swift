//
//  PermissionView.swift
//  ble
//
//  Created by Moshe Gottlieb on 02.01.25.
//

import SwiftUI


struct PermissionModifier : ViewModifier {
    
    @Binding var required:Bool
    let title:String
    let message:String
    var doIt:(()->())
    
    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $required)
         {
                VStack {
                    Button("Cancel") {}
                    Button("OK") { doIt() }
                }
            }
    message: {
        Text(message)
        }
    }
}

extension View {
    func permission(required:Binding<Bool>,title:String,message:String,doIt:@escaping ()->()) -> some View {
        modifier(PermissionModifier(required:required,title: title,message: message,doIt: doIt))
    }
}

struct demo : View {
    @State var required:Bool = false
    
    var body: some View {
        Text("Hello World!").permission(required: $required, title: "Title", message: "Message"){
            
        }
    }
}

#Preview {
    @Previewable @State var granted:Bool = false
    demo(required: true)
}

