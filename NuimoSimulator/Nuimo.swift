//
//  Nuimo.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import CoreBluetooth

class Nuimo : NSObject, CBPeripheralManagerDelegate {
    var deviceName = "Nuimo2"

    private lazy var peripheral: CBPeripheralManager = CBPeripheralManager(delegate: self, queue: nil)

    private var on = false

    private var characteristicForCharacteristicUUID = [CBUUID : CBMutableCharacteristic]()

    private var addedServices = [CBUUID]()

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
        updateButtonPressed(true)
    }

    func releaseButton() {
        updateButtonPressed(false)
    }

    private func updateButtonPressed(pressed: Bool) {
        let bytes = [pressed ? 1 : 0]
        peripheral.updateValue(NSData(bytes: bytes, length: bytes.count), forCharacteristic: characteristicForCharacteristicUUID[sensorButtonCharacteristicUUID]!, onSubscribedCentrals: nil)
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
                //TODO: Send matrix as bit array to some new delegate
                peripheral.respondToRequest(request, withResult: .Success)
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
        //TODO: What do we need to do here?
        print("peripheralManagerIsReadyToUpdateSubscribers")
    }
}

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
