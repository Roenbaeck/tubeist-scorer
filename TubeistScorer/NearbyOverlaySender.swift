@preconcurrency import CoreBluetooth
import CryptoKit
import SwiftUI

@MainActor @Observable
final class NearbyOverlaySender: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    enum ConnectionState {
        case unpaired, connecting, checking, paired, reconnecting, lost

        var hasConfirmedPairing: Bool {
            switch self {
            case .paired, .checking, .reconnecting, .lost: true
            case .unpaired, .connecting: false
            }
        }

        var isInProgress: Bool {
            switch self {
            case .connecting, .checking, .reconnecting: true
            case .unpaired, .paired, .lost: false
            }
        }
    }

    struct Receiver: Identifiable {
        let id: UUID
        let name: String
    }

    private struct Transmission {
        let frame: NearbyOverlayWire.Frame
        var offset = 0
    }

    private static let serviceID = CBUUID(string: NearbyOverlayWire.service)
    private static let inputID = CBUUID(string: NearbyOverlayWire.input)

    private(set) var receivers: [Receiver] = []
    private(set) var status = "Find Tubeist after it starts receiving."
    private(set) var connectionState: ConnectionState = .unpaired
    var isConnecting: Bool { connectionState.isInProgress }
    var isConnected: Bool { connectionState == .paired }

    @ObservationIgnored private var bluetooth: CBCentralManager?
    @ObservationIgnored private var discovered: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var target: CBPeripheral?
    @ObservationIgnored private var input: CBCharacteristic?
    @ObservationIgnored private var code: String?
    @ObservationIgnored private var transmission: Transmission?
    @ObservationIgnored private var cachedPackage: Data?
    @ObservationIgnored private var digest: Data?
    @ObservationIgnored private var latestUpdate: Data?
    @ObservationIgnored private var sentUpdate: Data?
    @ObservationIgnored private var canSendUpdates = false
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var discoveryRetryTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectDelay = 1
    @ObservationIgnored private var transportDeadline: ContinuousClock.Instant?
    @ObservationIgnored private var responseTimeoutTask: Task<Void, Never>?
    @ObservationIgnored private var triedRenewingAuthorization = false

    static func isPairingCode(_ code: String) -> Bool {
        code.utf8.count == 6 && code.utf8.allSatisfy { (48...57).contains($0) }
    }

    func scan() {
        guard target == nil else { return }
        wantsScan = true
        receivers.removeAll()
        discovered.removeAll()
        if let bluetooth {
            centralManagerDidUpdateState(bluetooth)
        } else {
            status = "Starting Bluetooth…"
            bluetooth = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func stopScanning() {
        wantsScan = false
        cancelDiscoveryRetries()
        bluetooth?.stopScan()
    }

    func connect(to receiver: Receiver, code: String) {
        guard target == nil, Self.isPairingCode(code),
              let bluetooth, bluetooth.state == .poweredOn,
              let peripheral = discovered[receiver.id] else { return }
        do {
            if cachedPackage == nil {
                let package = try Self.loadOverlayPackage()
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let bytes = try encoder.encode(package)
                guard bytes.count <= NearbyOverlayWire.Kind.package.maximumLength else {
                    status = "The overlay package exceeds Tubeist’s Bluetooth limit."
                    return
                }
                cachedPackage = bytes
                digest = Data(SHA256.hash(data: bytes))
            }
        } catch {
            status = "Could not prepare the overlay package."
            return
        }
        stopScanning()
        target = peripheral
        self.code = code
        connectionState = .connecting
        status = "Connecting to \(receiver.name)…"
        connect(to: peripheral, using: bluetooth)
    }

    func disconnect(failure: String? = nil) {
        connectionState = failure != nil && connectionState.hasConfirmedPairing ? .lost : .unpaired
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectDelay = 1
        let peripheral = target
        target = nil
        if let peripheral { bluetooth?.cancelPeripheralConnection(peripheral) }
        resetTransport()
        code = nil
        status = failure ?? "Disconnected."
    }

    func update(_ scoreboard: Scoreboard) {
        guard let bytes = try? scoreboard.overlayUpdateData(),
              bytes.count <= NearbyOverlayWire.Kind.update.maximumLength else { return }
        latestUpdate = bytes
        sendLatestUpdate()
    }

    func recheckConnection(announcesProgress: Bool = true) {
        guard isConnected, transmission == nil, let latestUpdate else { return }
        if announcesProgress {
            connectionState = .checking
            status = "Checking connection to Tubeist…"
        }
        send(.update, payload: latestUpdate)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let target, input == nil, target.state == .disconnected {
                connect(to: target, using: central)
            } else if target == nil, wantsScan {
                startDiscovery(on: central)
            }
        case .poweredOff, .resetting:
            cancelDiscoveryRetries()
            resetTransport()
            if target != nil { beginReconnecting() }
            status = central.state == .poweredOff ? "Turn on Bluetooth to connect." : "Restarting Bluetooth…"
        case .unauthorized: disconnect(failure: "Allow Bluetooth for Tubeist Scorer in iOS Settings.")
        case .unsupported: disconnect(failure: "Bluetooth LE is unavailable on this device.")
        default: status = "Starting Bluetooth…"
        }
    }

    private func startDiscovery(on central: CBCentralManager) {
        cancelDiscoveryRetries()
        status = "Looking for nearby Tubeist devices…"
        requestScan(on: central)
        guard receivers.isEmpty else { return }
        discoveryRetryTask = Task { [weak self] in
            for delay in [2, 4, 6] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, let bluetooth = self.bluetooth, bluetooth.state == .poweredOn,
                      self.wantsScan, self.target == nil, self.receivers.isEmpty else { return }
                self.requestScan(on: bluetooth)
            }
            guard let self, self.wantsScan, self.receivers.isEmpty else { return }
            self.discoveryRetryTask = nil
            self.status = "Still looking. Start receiving or refresh discovery in Tubeist."
        }
    }

    private func requestScan(on central: CBCentralManager) {
        central.stopScan()
        for peripheral in central.retrieveConnectedPeripherals(withServices: [Self.serviceID]) {
            rememberReceiver(peripheral, name: peripheral.name)
        }
        central.scanForPeripherals(withServices: [Self.serviceID])
    }

    private func cancelDiscoveryRetries() {
        discoveryRetryTask?.cancel()
        discoveryRetryTask = nil
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard wantsScan, target == nil else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        rememberReceiver(peripheral, name: name)
    }

    private func rememberReceiver(_ peripheral: CBPeripheral, name: String?) {
        if discovered.updateValue(peripheral, forKey: peripheral.identifier) == nil {
            receivers.append(Receiver(id: peripheral.identifier, name: name ?? "Tubeist"))
            cancelDiscoveryRetries()
            status = "Enter the pairing code from Tubeist and select the receiver."
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard target === peripheral else { return }
        peripheral.delegate = self
        status = "Finding the overlay receiver…"
        noteTransportProgress()
        peripheral.discoverServices([Self.serviceID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard target === peripheral else { return }
        recoverTransport(failure: "Could not connect. Check that Tubeist is receiving.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard target === peripheral else { return }
        resetTransport()
        beginReconnecting()
        scheduleReconnect()
    }

    private func connect(to peripheral: CBPeripheral, using central: CBCentralManager) {
        // For an established session, Core Bluetooth can wait for the phone to
        // come back into range. Start the response deadline after it connects.
        if !connectionState.hasConfirmedPairing {
            noteTransportProgress()
        }
        central.connect(peripheral)
    }

    private func recoverTransport(failure: String) {
        guard connectionState.hasConfirmedPairing, let target, let bluetooth else {
            disconnect(failure: failure)
            return
        }
        resetTransport()
        beginReconnecting()
        guard bluetooth.state == .poweredOn else { return }
        switch target.state {
        case .disconnected:
            scheduleReconnect()
        case .connected, .connecting:
            // The disconnect callback will schedule the next attempt.
            bluetooth.cancelPeripheralConnection(target)
        case .disconnecting:
            break
        @unknown default:
            bluetooth.cancelPeripheralConnection(target)
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = Duration.seconds(reconnectDelay)
        reconnectDelay = min(reconnectDelay * 2, 8)
        reconnectTask = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self, let central = self.bluetooth, let target = self.target,
                  central.state == .poweredOn, target.state == .disconnected else { return }
            self.reconnectTask = nil
            self.connect(to: target, using: central)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard target === peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else {
            recoverTransport(failure: "Tubeist’s overlay receiver is unavailable.")
            return
        }
        noteTransportProgress()
        peripheral.discoverCharacteristics([Self.inputID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard target === peripheral else { return }
        guard error == nil, let characteristic = service.characteristics?.first(where: { $0.uuid == Self.inputID }),
              let code else {
            recoverTransport(failure: "Tubeist’s overlay receiver is unavailable.")
            return
        }
        input = characteristic
        status = "Pairing with Tubeist…"
        send(.pair, payload: Data(code.utf8))
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard target === peripheral, invalidatedServices.contains(where: { $0.uuid == Self.serviceID }) else { return }
        recoverTransport(failure: "Tubeist stopped receiving. Start receiving there to pair again.")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard target === peripheral, characteristic === input, let transmission else { return }
        noteTransportProgress()
        let frame = transmission.frame
        if let error {
            self.transmission = nil
            let failure = error as NSError
            let transportErrors: [CBError.Code] = [.notConnected, .peripheralDisconnected, .connectionTimeout, .connectionFailed]
            if failure.domain == CBErrorDomain, transportErrors.contains(where: { $0.rawValue == failure.code }) {
                recoverTransport(failure: "The Bluetooth connection to Tubeist was interrupted.")
            } else if frame.kind == .checkPackage, failure.domain == CBATTErrorDomain,
               failure.code == CBATTError.Code.attributeNotFound.rawValue, let cachedPackage {
                status = "Sending the overlay package…"
                send(.package, payload: cachedPackage)
            } else if frame.kind != .pair, !triedRenewingAuthorization, let code,
                      failure.domain == CBATTErrorDomain,
                      failure.code == CBATTError.Code.insufficientAuthorization.rawValue {
                triedRenewingAuthorization = true
                canSendUpdates = false
                beginReconnecting()
                status = "Renewing overlay pairing…"
                send(.pair, payload: Data(code.utf8))
            } else {
                disconnect(failure: frame.kind == .pair
                    ? "Pairing failed. Check the current code or choose New pairing code on Tubeist."
                    : "Tubeist could not receive the overlay. Reconnect to try again.")
            }
            return
        }
        if transmission.offset < frame.payload.count {
            writeNextChunk()
            return
        }
        self.transmission = nil
        switch frame.kind {
        case .pair:
            if let digest { send(.checkPackage, payload: digest) }
        case .checkPackage, .package:
            canSendUpdates = true
            sentUpdate = nil
        case .update:
            clearResponseTimeout()
            triedRenewingAuthorization = false
            reconnectDelay = 1
            sentUpdate = frame.payload
            connectionState = .paired
            status = "Connected to Tubeist."
        }
        sendLatestUpdate()
    }

    private func beginReconnecting() {
        connectionState = connectionState.hasConfirmedPairing ? .reconnecting : .connecting
        status = connectionState == .reconnecting ? "Connection lost. Reconnecting…" : "Trying to connect again…"
    }

    private func noteTransportProgress() {
        let clock = ContinuousClock()
        transportDeadline = clock.now.advanced(by: .seconds(30))
        guard responseTimeoutTask == nil else { return }
        responseTimeoutTask = Task { [weak self] in
            while let deadline = self?.transportDeadline {
                do { try await clock.sleep(until: deadline) } catch { return }
                guard let self, let currentDeadline = self.transportDeadline else { return }
                guard clock.now >= currentDeadline else { continue }
                self.recoverTransport(failure: "Tubeist didn’t respond. Check that it’s receiving, then reconnect.")
                return
            }
        }
    }

    private func clearResponseTimeout() {
        responseTimeoutTask?.cancel()
        responseTimeoutTask = nil
        transportDeadline = nil
    }

    private func resetTransport() {
        clearResponseTimeout()
        triedRenewingAuthorization = false
        input = nil
        transmission = nil
        sentUpdate = nil
        canSendUpdates = false
    }

    private func sendLatestUpdate() {
        guard canSendUpdates, transmission == nil, let latestUpdate, latestUpdate != sentUpdate else { return }
        send(.update, payload: latestUpdate)
    }

    private func send(_ kind: NearbyOverlayWire.Kind, payload: Data) {
        noteTransportProgress()
        transmission = Transmission(frame: .init(kind: kind, payload: payload))
        writeNextChunk()
    }

    private func writeNextChunk() {
        guard let target, let input, var transmission else { return }
        // Fit a single ATT write so the receiver can acknowledge each chunk as it arrives.
        let limit = min(target.maximumWriteValueLength(for: .withResponse),
                        target.maximumWriteValueLength(for: .withoutResponse))
        guard limit > NearbyOverlayWire.headerSize else {
            disconnect(failure: "The Bluetooth link could not carry an overlay update.")
            return
        }
        let chunk = transmission.frame.chunk(from: transmission.offset, limit: limit)
        transmission.offset = chunk.nextOffset
        self.transmission = transmission
        target.writeValue(chunk.bytes, for: input, type: .withResponse)
    }

    private static func loadOverlayPackage() throws -> NearbyOverlayWire.Package {
        guard let root = Bundle.main.url(forResource: "Overlay", withExtension: nil),
              let entries = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
              ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var files: [String: Data] = [:]
        for case let url as URL in entries {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let name = url.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
            files[name] = try Data(contentsOf: url)
        }
        return .init(name: "Tubeist Scorer", entry: "index.html", files: files)
    }
}

struct NearbyOverlayConnectionView: View {
    let sender: NearbyOverlaySender
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bluetooth") {
                    Text(sender.status)
                        .accessibilityIdentifier("nearby-overlay-connection-status")
                    if sender.isConnected || sender.isConnecting {
                        Button(sender.isConnected ? "Disconnect" : "Cancel connection") {
                            sender.disconnect()
                            sender.scan()
                        }
                    } else {
                        TextField("Pairing code", text: $code)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("nearby-overlay-pairing-code")
                        ForEach(sender.receivers) { receiver in
                            Button("Connect to \(receiver.name)") {
                                sender.connect(to: receiver, code: code)
                            }
                            .disabled(!NearbyOverlaySender.isPairingCode(code))
                        }
                        Button("Scan again") { sender.scan() }
                    }
                }
            }
            .navigationTitle("Connect to Tubeist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { sender.scan() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { sender.scan() }
            }
            .onDisappear { sender.stopScanning() }
        }
    }
}
