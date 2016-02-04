//
//  Nuimo.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import Swift
import Foundation
import CoreBluetooth

class Nuimo : NSObject, CBPeripheralManagerDelegate {
    typealias CanUpdateValue = () -> (Bool)
    typealias OnValueUpdated = () -> ()
    typealias OnValueNotUpdated = () -> ()

    var delegate: NuimoDelegate?

    private let deviceName = "Nuimo"
    private let singleRotationValue = 2800

    private lazy var peripheral: CBPeripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    private var on = false
    private var characteristicForCharacteristicUUID = [CBUUID : CBMutableCharacteristic]()
    private var addedServices = [CBUUID]()
    private var updateQueue = [(CBUUID, [UInt8])]()
    private var accumulatedRotationDelta = 0.0
    private var lastRotationEventDate = NSDate()
    private let maxRotationEventsPerSecond = 10

    override init() {
        super.init()
    }

    func powerOn() {
        guard peripheral.state == .PoweredOn else { return }
        guard !on else { return }

        on = true
        reset()

        // Add services
        nuimoServiceUUIDs
            .map { serviceUUID in
                return CBMutableService(type: serviceUUID, primary: true).then { service in
                    service.characteristics = (nuimoCharactericUUIDsForServiceUUID[serviceUUID]!).map { characteristicUUID in
                        CBMutableCharacteristic(type: characteristicUUID, properties: characteristicPropertiesForCharacteristicUUID[characteristicUUID]!, value: nil, permissions: attributePermissionsForCharacteristicUUID[characteristicUUID]!).then {
                            characteristicForCharacteristicUUID[characteristicUUID] = $0
                        }
                    }
                }
            }
            .forEach(peripheral.addService)
    }
    
    func powerOff() {
        guard on else { return }

        on = false
        reset()

        //TODO: Hot to cut off existing connections?
    }

    private func reset() {
        accumulatedRotationDelta = 0.0
        updateQueue.removeAll()
        peripheral.stopAdvertising()
        peripheral.removeAllServices()
        addedServices.removeAll()
        characteristicForCharacteristicUUID.removeAll()
    }

    private func startAdvertising() {
        guard !peripheral.isAdvertising else { return }
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey :    deviceName,
            CBAdvertisementDataServiceUUIDsKey : nuimoServiceUUIDs])
    }

    //MARK: User input

    func pressButton() {
        updateValue([1], forCharacteristicUUID: sensorButtonCharacteristicUUID)
    }

    func releaseButton() {
        updateValue([0], forCharacteristicUUID: sensorButtonCharacteristicUUID)
    }

    func swipe(direction: NuimoSwipeDirection) {
        updateValue([UInt8(direction.rawValue)], forCharacteristicUUID: sensorTouchCharacteristicUUID)
    }

    func rotate(delta: Double) {
        accumulatedRotationDelta += delta

        guard accumulatedRotationDelta != 0 else { return }
        guard Int(1.0 / -lastRotationEventDate.timeIntervalSinceNow) <= maxRotationEventsPerSecond else { return }

        let accumulatedRotationValue = Int16(Double(singleRotationValue) * accumulatedRotationDelta)
        let didSendValue = updateValue([UInt8(truncatingBitPattern: accumulatedRotationValue), UInt8(truncatingBitPattern: accumulatedRotationValue >> 8)], forCharacteristicUUID: sensorRotationCharacteristicUUID, autoQueueIfNotSend: false)
        if didSendValue {
            accumulatedRotationDelta = 0.0
            lastRotationEventDate = NSDate()
        }
    }

    private func updateValue(value: [UInt8], forCharacteristicUUID characteristicUUID: CBUUID, autoQueueIfNotSend: Bool = true) -> Bool {
        guard let characteristic = characteristicForCharacteristicUUID[characteristicUUID] where on else { return false }

        let didSendValue = peripheral.updateValue(NSData(bytes: value, length: value.count), forCharacteristic: characteristic, onSubscribedCentrals: nil)
        if !didSendValue && autoQueueIfNotSend {
            updateQueue.append((characteristicUUID, value))
        }
        return didSendValue
    }

    //MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .PoweredOn:  powerOn()
        default:          powerOff()
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        if let error = error {
            print("Cannot add service", error.localizedDescription, service.UUID)
            return
        }

        guard nuimoServiceUUIDs.contains(service.UUID) else { return }

        addedServices.append(service.UUID)

        if addedServices.count == nuimoServiceUUIDs.count {
            startAdvertising()
        }
    }

    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        if let error = error {
            print("Cannot start advertising", error.localizedDescription)
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        switch request.characteristic.UUID {
        case genericAccessDeviceNameCharacteristicUUID:
            request.value = deviceName.dataUsingEncoding(NSUTF8StringEncoding)
            peripheral.respondToRequest(request, withResult: .Success)
        case batteryCharacteristicUUID:
            let bytes = [100]
            request.value = NSData(bytes: bytes, length: bytes.count)
            peripheral.respondToRequest(request, withResult: .Success)
        case deviceInformationCharacteristicUUID:
            //TODO: Respond request
            fallthrough
        default:
            peripheral.respondToRequest(request, withResult: .RequestNotSupported)
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        requests.forEach { request in
            switch request.characteristic.UUID {
            case ledMatrixCharacteristicUUID:
                guard let data = request.value where data.length == 13 else {
                    peripheral.respondToRequest(request, withResult: .InvalidAttributeValueLength)
                    break
                }
                let bytes = UnsafePointer<UInt8>(data.bytes)
                let leds: [Bool] = (0...10).flatMap { i -> [Bool] in
                    let byte = bytes[i]
                    return (0...7).map { (1 << $0) & byte > 0 }
                }
                let brightness = Double(bytes.advancedBy(11).memory) / 255.0
                let duration = Double(bytes.advancedBy(12).memory) * 10.0

                peripheral.respondToRequest(request, withResult: .Success)

                delegate?.nuimo(self, didReceiveLEDMatrix: NuimoLEDMatrix(leds: leds, brightness: brightness, duration: duration))
            default:
                peripheral.respondToRequest(request, withResult: .RequestNotSupported)
            }
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print("Subscribed to ", characteristic.UUID)
    }

    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print("Unsubscribed from ", characteristic.UUID)
    }

    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        while updateQueue.count > 0 {
            let (characteristicUUID, value) = updateQueue.removeFirst()
            updateValue(value, forCharacteristicUUID: characteristicUUID, autoQueueIfNotSend: true)
        }
    }
}

enum NuimoSwipeDirection: Int {
    case Left = 0
    case Right = 1
    case Up = 2
    case Down = 3
}

protocol NuimoDelegate {
    func nuimo(nuimo: Nuimo, didReceiveLEDMatrix ledMatrix: NuimoLEDMatrix)
}

struct NuimoLEDMatrix {
    var leds: [Bool]
    var brightness: Double
    var duration: Double
}

//MARK: Nuimo GATT specification

private let genericAccessServiceUUID                      = CBUUID(string: "1800")
private let genericAccessDeviceNameCharacteristicUUID     = CBUUID(string: "2A00")
private let genericAccessAppearanceCharacteristicUUID     = CBUUID(string: "2A01")
private let genericAccessConnParametersCharacteristicUUID = CBUUID(string: "2A04")
private let genericAttributeServiceUUID         =           CBUUID(string: "1801")
private let batteryServiceUUID                  =           CBUUID(string: "180F")
private let batteryCharacteristicUUID           =           CBUUID(string: "2A19")
private let deviceInformationServiceUUID        =           CBUUID(string: "180A")
private let deviceInformationCharacteristicUUID =           CBUUID(string: "2A29")
private let ledMatrixServiceUUID                =           CBUUID(string: "F29B1523-CB19-40F3-BE5C-7241ECB82FD1")
private let ledMatrixCharacteristicUUID         =           CBUUID(string: "F29B1524-CB19-40F3-BE5C-7241ECB82FD1")
private let sensorServiceUUID                   =           CBUUID(string: "F29B1525-CB19-40F3-BE5C-7241ECB82FD2")
private let sensorFlyCharacteristicUUID         =           CBUUID(string: "F29B1526-CB19-40F3-BE5C-7241ECB82FD2")
private let sensorTouchCharacteristicUUID       =           CBUUID(string: "F29B1527-CB19-40F3-BE5C-7241ECB82FD2")
private let sensorRotationCharacteristicUUID    =           CBUUID(string: "F29B1528-CB19-40F3-BE5C-7241ECB82FD2")
private let sensorButtonCharacteristicUUID      =           CBUUID(string: "F29B1529-CB19-40F3-BE5C-7241ECB82FD2")

private let nuimoServiceUUIDs: [CBUUID] = [
    //genericAccessServiceUUID,
    //genericAttributeServiceUUID,
    //batteryServiceUUID,
    deviceInformationServiceUUID,
    ledMatrixServiceUUID,
    sensorServiceUUID
]

private let nuimoCharactericUUIDsForServiceUUID = [
    genericAccessServiceUUID : [genericAccessDeviceNameCharacteristicUUID, genericAccessAppearanceCharacteristicUUID, genericAccessConnParametersCharacteristicUUID],
    genericAttributeServiceUUID: [],
    batteryServiceUUID: [batteryCharacteristicUUID],
    deviceInformationServiceUUID: [deviceInformationCharacteristicUUID],
    ledMatrixServiceUUID: [ledMatrixCharacteristicUUID],
    sensorServiceUUID: [
        sensorFlyCharacteristicUUID,
        sensorTouchCharacteristicUUID,
        sensorRotationCharacteristicUUID,
        sensorButtonCharacteristicUUID
    ]
]

private let characteristicPropertiesForCharacteristicUUID : [CBUUID : CBCharacteristicProperties] = [
    genericAccessDeviceNameCharacteristicUUID :     [.Read, .Write],
    genericAccessAppearanceCharacteristicUUID :     [.Read],
    genericAccessConnParametersCharacteristicUUID : [.Read],
    batteryCharacteristicUUID :                     [.Read, .Notify],
    deviceInformationCharacteristicUUID :           [.Read],
    ledMatrixCharacteristicUUID :                   [.Write],
    sensorFlyCharacteristicUUID :                   [.Notify],
    sensorTouchCharacteristicUUID :                 [.Notify],
    sensorRotationCharacteristicUUID :              [.Notify],
    sensorButtonCharacteristicUUID :                [.Notify]
]

private let attributePermissionsForCharacteristicUUID : [CBUUID : CBAttributePermissions] = [
    genericAccessDeviceNameCharacteristicUUID :     [.Readable, .Writeable],
    genericAccessAppearanceCharacteristicUUID :     [.Readable],
    genericAccessConnParametersCharacteristicUUID : [.Readable],
    batteryCharacteristicUUID :                     [.Readable],
    deviceInformationCharacteristicUUID :           [.Readable],
    ledMatrixCharacteristicUUID :                   [.Writeable],
    sensorFlyCharacteristicUUID :                   [.Readable],
    sensorTouchCharacteristicUUID :                 [.Readable],
    sensorRotationCharacteristicUUID :              [.Readable],
    sensorButtonCharacteristicUUID :                [.Readable]
]
