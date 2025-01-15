//
//  BLE.swift
//  bleTest
//
//  Created by Moshe Gottlieb on 31.12.24.
//

import Foundation
import CoreBluetooth
import SwiftUI
import UserNotifications

@Observable
class BLE : NSObject, CBCentralManagerDelegate,CBPeripheralDelegate {
    
    
    var state : String {
        switch manager.state {
        case .poweredOff:
            return "Powered off"
        case .poweredOn:
            return "Powered on"
        case .unsupported:
            return "Unsupported"
        case .unauthorized:
            return "Unauthorized"
        case .unknown:
            return "Unknown"
        case .resetting:
            return "Resetting"
        @unknown default:
            fatalError()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Is Powered Off.")
        case .poweredOn:
            print("Is Powered On.")
            startScanning()
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
            print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
            print("Error")
        }
    }
    
    
    func startScanning(){
        guard !requiresAuthorization else { return }
        isReady = false
        manager.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
    }
    
    private static var _shared = BLE()
    
    @discardableResult static func shared() -> BLE {
        return _shared
    }
    
    var manager: CBCentralManager! = nil
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        self.peripheral = peripheral
        
        peripheral.delegate = self
        
        print("Peripheral Discovered: \(peripheral.identifier)")
        print("Peripheral name: \(peripheral.name ?? "No name")")
        central.connect(peripheral)
        manager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected")
        peripheral.discoverServices([CBUUIDs.BLEService_UUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
        isReady = true
    }
    
    private override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        requiresAuthorization = authorization != .allowedAlways
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("Failed to connect")
        startScanning()
    }

    func didDisconnect(){
        print("Disconnected")
        UserDefaults.standard.set(mailCount,forKey: ContentView.lastMailboxCountKey)
        UserDefaults.standard.set(Date(),forKey: ContentView.lastMailboxDateKey)
        mailCount = nil
        startScanning()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        didDisconnect()
    }

    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        print("Disconnected. Reconnecting: \(isReconnecting)")
        if (!isReconnecting){
            didDisconnect()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error = error {
            print("Error writing value: \(error.localizedDescription)")
        } else {
            print( "Value written successfully")
            isReady = true
            peripheral.readValue(for: characteristic)
        }
    }
    
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        switch event {
        case .peerConnected:
            print( "Peer Connected")
        case .peerDisconnected:
            print( "Peer Disconnected")
            didDisconnect()
        @unknown default:
            fatalError()
        }
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics.")
        
        for characteristic in characteristics {
            
            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Rx)  {
                
                rxCharacteristic = characteristic
                
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
                
                print("RX Characteristic: \(characteristic.uuid)")
            }
            
            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Tx){
                
                txCharacteristic = characteristic
                
                print("TX Characteristic: \(characteristic.uuid)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard characteristic == rxCharacteristic else { return }
        mailCount = getValue(characteristic: characteristic)
    }
    
    func setValue(characteristic: CBCharacteristic,value:UInt16){
        // works for any endian, convert to little endian
        guard let txCharacteristic = txCharacteristic else { return }
        let data = Data([UInt8(value >> 8),UInt8(value & 0xFF)])
        peripheral?.writeValue(data, for: txCharacteristic, type: .withResponse)
    }
    
    func getValue(characteristic: CBCharacteristic) -> UInt16 {
        guard let data = characteristic.value else {
            print("Error reading characteristic, no data")
            return 0
        }
        guard data.count == 2 else {
            print("Error reading characteristic, expected two bytes, got \(data.count)")
            return 0
        }
        // works for any endian
        let ret = UInt16(data[0]) << 8 | UInt16(data[1])
        print("Read the value: \(ret)")
        return ret
    }

    private(set) var mailCount : UInt16? {
        didSet {
            if let peripheral = peripheral, let mail_count = mailCount, (UserDefaults.standard.bool(forKey: ContentView.showNotificationsKey) && mail_count > 0){
                let content = UNMutableNotificationContent()
                content.title = "You have mail!"
                content.body = "\(mail_count) items in \(peripheral.name ?? "Unknown")"
                content.sound = UNNotificationSound(named:UNNotificationSoundName("reverby.wav"))
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            }
        }
    }
    
    var isReady : Bool = false
    
    var authorization : CBManagerAuthorization {
        return CBCentralManager.authorization
    }
    
    var requiresAuthorization : Bool = true
    
    func requestAuthorization(){
        requiresAuthorization = false
        startScanning()
    }
    
}


struct CBUUIDs{
    
    static let kBLEService_UUID = "ca7b329c-db95-4a4e-8903-19eabaa8c17a"
    static let kBLE_Characteristic_uuid_Tx = "44acd597-7535-4dc2-b1e2-081657b5ae47"
    static let kBLE_Characteristic_uuid_Rx = "44acd597-7535-4dc2-b1e2-081657b5ae47"
    
    static let BLEService_UUID = CBUUID(string: kBLEService_UUID)
    static let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
    static let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)
    
}
