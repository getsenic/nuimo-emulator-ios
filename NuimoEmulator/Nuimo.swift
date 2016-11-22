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
    private var lastRotationEventDate = Date()
    private let maxRotationEventsPerSecond = 10

    func powerOn() {
        guard peripheral.state == .poweredOn else { return }
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
            .forEach(peripheral.add(_:))

        delegate?.nuimo(self, didChangeOnState: true)
    }
    
    private func powerOff() {
        guard on else { return }

        on = false
        reset()

        delegate?.nuimo(self, didChangeOnState: false)
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
        let _ = update(value: [1], forCharacteristicUUID: sensorButtonCharacteristicUUID)
    }

    func releaseButton() {
        let _ = update(value: [0], forCharacteristicUUID: sensorButtonCharacteristicUUID)
    }

    func swipe(_ direction: NuimoSwipeDirection) {
        let _ = update(value: [UInt8(direction.rawValue)], forCharacteristicUUID: sensorTouchCharacteristicUUID)
    }

    func rotate(_ delta: Double) {
        accumulatedRotationDelta += delta

        guard accumulatedRotationDelta != 0 else { return }
        guard Int(1.0 / -lastRotationEventDate.timeIntervalSinceNow) <= maxRotationEventsPerSecond else { return }

        let accumulatedRotationValue = Int16(Double(singleRotationValue) * accumulatedRotationDelta)
        let didSendValue = update(value: [UInt8(truncatingBitPattern: accumulatedRotationValue), UInt8(truncatingBitPattern: accumulatedRotationValue >> 8)], forCharacteristicUUID: sensorRotationCharacteristicUUID, autoQueueIfNotSend: false)
        if didSendValue {
            accumulatedRotationDelta = 0.0
            lastRotationEventDate = Date()
        }
    }

    private func update(value: [UInt8], forCharacteristicUUID characteristicUUID: CBUUID, autoQueueIfNotSend: Bool = true) -> Bool {
        guard let characteristic = characteristicForCharacteristicUUID[characteristicUUID], on else { return false }

        let didSendValue = peripheral.updateValue(Data(bytes: UnsafePointer<UInt8>(value), count: value.count), for: characteristic, onSubscribedCentrals: nil)
        if !didSendValue && autoQueueIfNotSend {
            updateQueue.append((characteristicUUID, value))
        }
        return didSendValue
    }

    //MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:  powerOn()
        default:          powerOff()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Cannot add service", error.localizedDescription, service.uuid)
            return
        }

        guard nuimoServiceUUIDs.contains(service.uuid) else { return }

        addedServices.append(service.uuid)

        if addedServices.count == nuimoServiceUUIDs.count {
            startAdvertising()
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Cannot start advertising", error.localizedDescription)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
        case genericAccessDeviceNameCharacteristicUUID:
            request.value = deviceName.data(using: String.Encoding.utf8)
            peripheral.respond(to: request, withResult: .success)
        case batteryCharacteristicUUID:
            let bytes = [100]
            request.value = Data(bytes: bytes, count: bytes.count)
            peripheral.respond(to: request, withResult: .success)
        case deviceInformationCharacteristicUUID:
            //TODO: Respond request
            fallthrough
        default:
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        requests.forEach { request in
            switch request.characteristic.uuid {
            case ledMatrixCharacteristicUUID:
                guard let data = request.value, data.count == 13 else {
                    peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                    break
                }
                let bytes = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
                let leds: [Bool] = (0...10).flatMap { i -> [Bool] in
                    let byte = bytes[i]
                    return (0...7).map { (1 << $0) & byte > 0 }
                }
                let brightness = Double(bytes.advanced(by:11).pointee) / 255.0
                let duration = Double(bytes.advanced(by:12).pointee) / 10.0

                peripheral.respond(to: request, withResult: .success)

                delegate?.nuimo(self, didReceiveLEDMatrix: NuimoLEDMatrix(leds: leds, brightness: brightness, duration: duration))
            default:
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Subscribed to ", characteristic.uuid)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Unsubscribed from ", characteristic.uuid)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        while updateQueue.count > 0 {
            let (characteristicUUID, value) = updateQueue.removeFirst()
            let _ = update(value: value, forCharacteristicUUID: characteristicUUID, autoQueueIfNotSend: true)
        }
    }
}

enum NuimoSwipeDirection: Int {
    case left = 0
    case right = 1
    case up = 2
    case down = 3
}

protocol NuimoDelegate {
    func nuimo(_ nuimo: Nuimo, didChangeOnState on: Bool)
    func nuimo(_ nuimo: Nuimo, didReceiveLEDMatrix ledMatrix: NuimoLEDMatrix)
}

class NuimoLEDMatrix {
    var leds: [Bool]
    var brightness: Double
    var duration: Double
    init(leds: [Bool], brightness: Double, duration: Double) {
        self.leds = leds
        self.brightness = brightness
        self.duration = duration
    }
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
    genericAccessDeviceNameCharacteristicUUID :     [.read, .write],
    genericAccessAppearanceCharacteristicUUID :     [.read],
    genericAccessConnParametersCharacteristicUUID : [.read],
    batteryCharacteristicUUID :                     [.read, .notify],
    deviceInformationCharacteristicUUID :           [.read],
    ledMatrixCharacteristicUUID :                   [.write],
    sensorFlyCharacteristicUUID :                   [.notify],
    sensorTouchCharacteristicUUID :                 [.notify],
    sensorRotationCharacteristicUUID :              [.notify],
    sensorButtonCharacteristicUUID :                [.notify]
]

private let attributePermissionsForCharacteristicUUID : [CBUUID : CBAttributePermissions] = [
    genericAccessDeviceNameCharacteristicUUID :     [.readable, .writeable],
    genericAccessAppearanceCharacteristicUUID :     [.readable],
    genericAccessConnParametersCharacteristicUUID : [.readable],
    batteryCharacteristicUUID :                     [.readable],
    deviceInformationCharacteristicUUID :           [.readable],
    ledMatrixCharacteristicUUID :                   [.writeable],
    sensorFlyCharacteristicUUID :                   [.readable],
    sensorTouchCharacteristicUUID :                 [.readable],
    sensorRotationCharacteristicUUID :              [.readable],
    sensorButtonCharacteristicUUID :                [.readable]
]
