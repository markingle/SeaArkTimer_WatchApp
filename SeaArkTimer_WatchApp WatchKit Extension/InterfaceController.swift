//
//  InterfaceController.swift
//  SeaArkTimer_WatchApp WatchKit Extension
//
//  Created by Mark Brady Ingle on 10/6/19.
//  Copyright © 2019 Mark Brady Ingle. All rights reserved.
//

import WatchKit
import Foundation

import CoreBluetooth


// MARK: - Core Bluetooth service IDs
let Livewell_Timer_Service_CBUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")


// MARK: - Core Bluetooth characteristic IDs
let Livewell_OnOff_Switch_Characteristic_CBUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a6")
let Livewell_OFFTIME_Characteristic_CBUUID = CBUUID(string: "beb5483e-36e1-4688-b7f6-ea07361b26b7")
let Livewell_ONTIME_Characteristic_CBUUID = CBUUID(string: "beb5483e-36e1-4688-b7f7-ea07361b26c8")
let Livewell_TIMER_Characteristic_CBUUID = CBUUID(string: "beb5483e-36e1-4688-b7f8-ea07361b26d9")


class InterfaceController: WKInterfaceController {

    var isOn = false
    var onTimeValue: Float = 0.0
  
    @IBOutlet weak var powerSwitch: WKInterfaceSwitch!
    
    @IBOutlet weak var onTimerSettingSlider: WKInterfaceSlider!
    
    @IBOutlet weak var offTimerSettingSlider: WKInterfaceSlider!
    
    @IBOutlet weak var timerValueLabel: WKInterfaceLabel!
    
    var centralManager: CBCentralManager!
    var SeaArkLivewellTimer: CBPeripheral?
    
    // Characteristics
    private var powerState: CBCharacteristic?
    private var onTimeSetting: CBCharacteristic?
    private var offTimeSetting: CBCharacteristic?
    private var currentTime: CBCharacteristic?
    
    @IBAction func powerSwitch(_ value: Bool) {
            isOn = value
            if value {
                WKInterfaceDevice.current().play(.click)
                powerSwitch.setTitle("Timer is On")
                print("On")
                let SwitchState = "1"
                let data = Data(SwitchState.utf8)
                print("data = ", data)
                writeonStateValueToChar(withCharacteristic: powerState!, withValue: data)
            } else {
                WKInterfaceDevice.current().play(.click)
                powerSwitch.setTitle("Timer is Off")
                print("Off")
                let SwitchState = "0"
                let data = Data(SwitchState.utf8)
                print("data = ", data)
                writeonStateValueToChar(withCharacteristic: powerState!, withValue: data)
            }
        }
    
    @IBAction func onTimeSettingChange(_ value: Float) {
        let onTimeString = String(value)
        print("ON Time Setting State Changed")
        let onTimerValue = String(onTimeString)
        let data = Data(onTimerValue.utf8)
        print("on Time Setting",data)
        writeonStateValueToChar(withCharacteristic: onTimeSetting!, withValue: data)
    }
    
    @IBAction func offTimeSettingChange(_ value: Float) {
        let offTimeString = String(value)
        print("OFF Time Setting State Changed")
        let offTimerValue = String(offTimeString)
        let data = Data(offTimerValue.utf8)
        print("ON Time Setting",data)
        writeonStateValueToChar(withCharacteristic: offTimeSetting!, withValue: data)
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        print("Hello Again")
        // Create a concurrent background queue for the central
        let centralQueue: DispatchQueue = DispatchQueue(label: "com.iosbrain.centralQueueName", attributes: .concurrent)
        
        // Create a central to scan for, connect to,
        // manage, and collect data from peripherals
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
        print("CB Mgr Ran")
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        cleanup()
    }
    
    func scan() {
      centralManager.scanForPeripherals(withServices: [Livewell_Timer_Service_CBUUID])
        print("Scanning For Peripherals")
        powerSwitch.setEnabled(false)
        onTimerSettingSlider.setEnabled(false)
        offTimerSettingSlider.setEnabled(false)
        powerSwitch.setTitle("Scanning...")
    }

    func cleanup() {
      guard SeaArkLivewellTimer?.state != .disconnected,
        let services = SeaArkLivewellTimer?.services else {
          centralManager.cancelPeripheralConnection(SeaArkLivewellTimer!)
          return
      }
      for service in services {
        if let characteristics = service.characteristics {
          for characteristic in characteristics {
            if characteristic.uuid.isEqual(Livewell_OFFTIME_Characteristic_CBUUID) {
              if characteristic.isNotifying {
                SeaArkLivewellTimer?.setNotifyValue(false, for: characteristic)
                return
              }
            }
          }
        }
      }
      centralManager.cancelPeripheralConnection(SeaArkLivewellTimer!)
    }
    
    func decodePeripheralState(peripheralState: CBPeripheralState) {
        
        switch peripheralState {
            case .disconnected:
                print("Peripheral state: disconnected")
            case .connected:
                print("Peripheral state: connected")
            case .connecting:
                print("Peripheral state: connecting")
            case .disconnecting:
                print("Peripheral state: disconnecting")
        default: break
        }
        
    } // END func decodePeripheralState(peripheralState
}

// MARK: - Central Manager delegate
extension InterfaceController: CBCentralManagerDelegate, CBPeripheralDelegate {
    
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn: scan();print("Hello Scan")
    case .poweredOff, .resetting: cleanup()
    default: return
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
      
      print("Peripheral Found ",peripheral.name!)
    powerSwitch.setTitle(String(peripheral.name!))
      decodePeripheralState(peripheralState: peripheral.state)
      // STEP 4.2: MUST store a reference to the peripheral in
      // class instance variable
      SeaArkLivewellTimer = peripheral
      // STEP 4.3: since ViewController
      // adopts the CBPeripheralDelegate protocol,
      // the SeaArkLivewellTimer must set its
      // delegate property to ViewController
      // (self)
      SeaArkLivewellTimer?.delegate = self
      
      // STEP 5: stop scanning to preserve battery life;
      // re-scan if disconnected
      centralManager?.stopScan()
      print("Stopped Scanning")
      
      // STEP 6: connect to the discovered peripheral of interest
      centralManager?.connect(SeaArkLivewellTimer!)
      powerSwitch.setEnabled(true)
      onTimerSettingSlider.setEnabled(true)
      offTimerSettingSlider.setEnabled(true)
      
  } // END func centralManager(... didDiscover peripheral

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    if let error = error { print(error.localizedDescription) }
    cleanup()
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    
    // STEP 8: look for services of interest on peripheral
    print("Did Connect....Looking for Timer")
    SeaArkLivewellTimer?.discoverServices([Livewell_Timer_Service_CBUUID])
    
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    powerSwitch.setEnabled(false)
    onTimerSettingSlider.setEnabled(false)
    offTimerSettingSlider.setEnabled(false)
    powerSwitch.setTitle("DX..Scanning")
    powerSwitch.setOn(false)
    centralManager?.scanForPeripherals(withServices: [Livewell_Timer_Service_CBUUID])
    print("Central Manager Looking!!")
  }

    
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    
    for service in peripheral.services! {
        
        if service.uuid == Livewell_Timer_Service_CBUUID {
            
            print("Service: \(service)")
            
            // STEP 9: look for characteristics of interest
            // within services of interest
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
            
            print("Characteristic: \(characteristic)")
            
            if characteristic.uuid == Livewell_OnOff_Switch_Characteristic_CBUUID{
                print("Power State")
                powerState = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == Livewell_OFFTIME_Characteristic_CBUUID{
                print("OFFTIME Found")
                offTimeSetting = characteristic
                
            }
            if characteristic.uuid == Livewell_ONTIME_Characteristic_CBUUID{
                print("ONTIME Found")
                onTimeSetting = characteristic
                
            }
            if characteristic.uuid == Livewell_TIMER_Characteristic_CBUUID{
                print("TIMER Found")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    } // END func peripheral(... didDiscoverCharacteristicsFor service
    
    func writeonStateValueToChar( withCharacteristic characteristic: CBCharacteristic, withValue value: Data) {
        if characteristic.properties.contains(.writeWithoutResponse) && SeaArkLivewellTimer != nil {
            SeaArkLivewellTimer?.writeValue(value, for: characteristic, type:.withoutResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid == Livewell_TIMER_Characteristic_CBUUID {
            
            // STEP 14: we generally have to decode BLE
            // data into human readable format
            let count_n_seconds = [UInt8](characteristic.value!)
            
            print("Timer count", count_n_seconds[0])

            DispatchQueue.main.async { () -> Void in
                self.timerValueLabel.setText(String(count_n_seconds[0]))
                            }
        } // END if characteristic.uuid ==...
        
        if characteristic.uuid == Livewell_OnOff_Switch_Characteristic_CBUUID {
            
            // STEP 14: we generally have to decode BLE
            // data into human readable format
            let Recieved_Switch_State = [UInt8](characteristic.value!)
            
            print("Power State", Recieved_Switch_State[0])

            DispatchQueue.main.async { () -> Void in
                if Recieved_Switch_State[0] == 1 {
                    self.powerSwitch.setEnabled(true)
                    self.powerSwitch.setOn(true)
                    self.powerSwitch.setTitle("Timer is ON")
                } else {
                    self.powerSwitch.setTitle("Timer is OFF")
                }
            }
        } // END if characteristic.uuid ==...
        
    } // END func peripheral(... didUpdateValueFor characteristic

}
