import Foundation
import Libbox
import Network
import NetworkExtension

@available(iOS 15.0, *)
final class LibboxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private unowned let provider: PacketTunnelProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?

    init(provider: PacketTunnelProvider) {
        self.provider = provider
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_ else {
            throw NSError(domain: "ForgeVPN.Libbox", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing TUN options"])
        }
        try blocking { try await self.configureTunnel(options, ret0_) }
    }

    private func configureTunnel(_ options: LibboxTunOptionsProtocol, _ result: UnsafeMutablePointer<Int32>) async throws {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU())

        if options.getAutoRoute() {
            let dnsServer = try options.getDNSServerAddress().value
            let dns = NEDNSSettings(servers: [dnsServer])
            dns.matchDomains = [""]
            dns.matchDomainsNoSearch = true
            settings.dnsSettings = dns

            let ipv4 = collectIPv4(options.getInet4Address())
            let ipv4Settings = NEIPv4Settings(addresses: ipv4.addresses, subnetMasks: ipv4.masks)
            ipv4Settings.includedRoutes = routes4(options.getInet4RouteAddress(), fallback: true)
            ipv4Settings.excludedRoutes = routes4(options.getInet4RouteExcludeAddress(), fallback: false)
            settings.ipv4Settings = ipv4Settings

            let ipv6 = collectIPv6(options.getInet6Address())
            let ipv6Settings = NEIPv6Settings(addresses: ipv6.addresses, networkPrefixLengths: ipv6.prefixes)
            ipv6Settings.includedRoutes = routes6(options.getInet6RouteAddress(), fallback: true)
            ipv6Settings.excludedRoutes = routes6(options.getInet6RouteExcludeAddress(), fallback: false)
            settings.ipv6Settings = ipv6Settings
        }

        networkSettings = settings
        try await provider.setTunnelNetworkSettings(settings)
        let tunFd = LibboxGetTunnelFileDescriptor()
        guard tunFd >= 0 else {
            throw NSError(domain: "ForgeVPN.Libbox", code: 2, userInfo: [NSLocalizedDescriptionKey: "libbox did not provide a tunnel file descriptor"])
        }
        result.pointee = tunFd
    }

    func usePlatformAutoDetectControl() -> Bool { false }
    func autoDetectControl(_: Int32) throws {}

    func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?, destinationPort _: Int32, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "ForgeVPN.Libbox", code: 3, userInfo: [NSLocalizedDescriptionKey: "Connection-owner lookup is unavailable on iOS"])
    }

    func packageName(byUid _: Int32, error _: NSErrorPointer) -> String { "" }

    func uid(byPackageName _: String?, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "ForgeVPN.Libbox", code: 4, userInfo: [NSLocalizedDescriptionKey: "Package lookup is unavailable on iOS"])
    }

    func useProcFS() -> Bool { false }
    func writeLog(_ message: String?) { if let message { provider.appendLog(message) } }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { path in
            guard path.status != .unsatisfied, let interface = path.availableInterfaces.first else {
                listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
                return
            }
            listener.updateDefaultInterface(interface.name, interfaceIndex: Int32(interface.index), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
        }
        monitor.start(queue: DispatchQueue(label: "dev.forge.vpn.network-monitor"))
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        let interfaces = (pathMonitor?.currentPath.availableInterfaces ?? []).map { item -> LibboxNetworkInterface in
            let interface = LibboxNetworkInterface()
            interface.name = item.name
            interface.index = Int32(item.index)
            interface.type = item.type == .wifi ? LibboxInterfaceTypeWIFI : item.type == .cellular ? LibboxInterfaceTypeCellular : item.type == .wiredEthernet ? LibboxInterfaceTypeEthernet : LibboxInterfaceTypeOther
            return interface
        }
        return NetworkInterfaceIterator(interfaces)
    }

    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }

    func clearDNSCache() {
        guard let settings = networkSettings else { return }
        Task {
            provider.reasserting = true
            defer { provider.reasserting = false }
            try? await provider.setTunnelNetworkSettings(nil)
            try? await provider.setTunnelNetworkSettings(settings)
        }
    }

    func readWIFIState() -> LibboxWIFIState? { nil }
    func serviceReload() throws { Task { try? await provider.reloadService() } }
    func postServiceClose() { reset(); provider.postServiceClose() }

    func getSystemProxyStatus() -> LibboxSystemProxyStatus? {
        LibboxSystemProxyStatus()
    }

    func setSystemProxyEnabled(_: Bool) throws {}
    func send(_: LibboxNotification?) throws {}

    func reset() { networkSettings = nil }

    private func collectIPv4(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> (addresses: [String], masks: [String]) {
        var addresses = [String](); var masks = [String]()
        while iterator?.hasNext() == true, let prefix = iterator?.next() {
            addresses.append(prefix.address()); masks.append(prefix.mask())
        }
        return (addresses, masks)
    }

    private func collectIPv6(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> (addresses: [String], prefixes: [NSNumber]) {
        var addresses = [String](); var prefixes = [NSNumber]()
        while iterator?.hasNext() == true, let prefix = iterator?.next() {
            addresses.append(prefix.address()); prefixes.append(NSNumber(value: prefix.prefix()))
        }
        return (addresses, prefixes)
    }

    private func routes4(_ iterator: LibboxRoutePrefixIteratorProtocol?, fallback: Bool) -> [NEIPv4Route] {
        var routes = [NEIPv4Route]()
        while iterator?.hasNext() == true, let prefix = iterator?.next() {
            routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
        }
        return routes.isEmpty && fallback ? [.default()] : routes
    }

    private func routes6(_ iterator: LibboxRoutePrefixIteratorProtocol?, fallback: Bool) -> [NEIPv6Route] {
        var routes = [NEIPv6Route]()
        while iterator?.hasNext() == true, let prefix = iterator?.next() {
            routes.append(NEIPv6Route(destinationAddress: prefix.address(), networkPrefixLength: NSNumber(value: prefix.prefix())))
        }
        return routes.isEmpty && fallback ? [.default()] : routes
    }

    private func blocking<T>(_ operation: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>!
        Task { result = await Result { try await operation() }; semaphore.signal() }
        semaphore.wait()
        return try result.get()
    }

    private final class NetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
        private var values: [LibboxNetworkInterface]
        private var index = 0
        init(_ values: [LibboxNetworkInterface]) { self.values = values }
        func hasNext() -> Bool { index < values.count }
        func next() -> LibboxNetworkInterface? {
            guard hasNext() else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }
}
