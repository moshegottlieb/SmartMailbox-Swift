//
//  ContentView.swift
//  ble
//
//  Created by Moshe Gottlieb on 01.01.25.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    
    
    static let showNotificationsKey = "showNotificationsKey"
    static let lastMailboxCountKey = "lastMailboxStateKey"
    static let lastMailboxDateKey = "lastMailboxDateKey"
    @AppStorage(Self.showNotificationsKey) var showNotifications : Bool = false
    @AppStorage(Self.lastMailboxCountKey) var lastCount : Int?
    @AppStorage(Self.lastMailboxDateKey) var lastDate : Date?
    
    var body: some View {
        VStack {
            HStack {
                Text("Smart Mailbox")
                Image(systemName: "envelope")
            }.font(.title3)
            Spacer()
            VStack {
                HStack {
                    Spacer()
                    GroupBox {
                        if let mail_count = BLE.shared().mailCount {
                            if mail_count > 0 {
                                HStack {
                                    Text("We have mail!").bold()
                                    Image(systemName: "envelope.badge.fill")
                                }.foregroundColor(.indigo)
                            } else {
                                HStack {
                                    Text("No mail!")
                                    Image(systemName: "envelope")
                                }
                            }
                        } else {
                            HStack {
                                Text("Not connected")
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")}
                            .foregroundColor(.gray)
                        }
                    }.padding(EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40))
                    Spacer()
                }.layoutPriority(1)
            }
            Spacer()
            HStack {
                Toggle(isOn:$showNotifications){
                    EmptyView()
                }.labelsHidden()
                Text("Show notifications?")
            }
            Text(statusLine)
                .font(.footnote)
                .foregroundColor(Color.gray)
        }
        .padding()
        .background(BLE.shared().isReady ? Color.blue.opacity(0.4) : Color.clear)
        .onAppear(){
            lastCount = 0
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    requiresNotificationPermission = true
                }
            }
        }
        .permission(required: $requiresNotificationPermission, title: "Notifications", message: "Because") {
            Task {
                let options:UNAuthorizationOptions = [.alert , .sound, .badge]
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: options)
            }
        }
    }
    var statusLine : String {
        var ret = "State: \(BLE.shared().state)"
        if let lastCount = lastCount {
            ret += "\nLast count was \(lastCount)"
        }
        if let lastDate = lastDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            ret += " at \(formatter.string(from: lastDate))"
        }
        return ret
    }
    
    @State var requiresNotificationPermission : Bool = false
    
}

#Preview {
    ContentView()
}
