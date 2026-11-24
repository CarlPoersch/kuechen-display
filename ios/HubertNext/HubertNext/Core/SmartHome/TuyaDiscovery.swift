import Foundation
import Network

// ============================================================
// Steckdosen im WLAN finden – ohne UDP-Broadcast.
// Warum: Broadcasts empfangen darf eine iOS-App nur mit Apples Multicast-Berechtigung.
// Stattdessen: alle Adressen im eigenen Netz (höchstens die eigene /24) auf Port 6668
// prüfen. Welche Steckdose hinter einer Adresse steckt, zeigt sich am passenden Schlüssel.
// ============================================================

enum TuyaDiscovery {
    /// Eigene WLAN-Adresse (IPv4) und Netzmaske
    static func wifiAddress() -> (ip: UInt32, mask: UInt32)? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var best: (UInt32, UInt32)?
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let addr = i.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET), let maskPtr = i.ifa_netmask else { continue }
            let name = String(cString: i.ifa_name)
            guard name.hasPrefix("en") else { continue }       // en0 = WLAN (en1… z. B. Adapter)
            let ip = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            if ip == 0 || (ip >> 16) == 0xA9FE { continue }   // 169.254.x.x = kein echtes Netz
            if name == "en0" { return (ip, mask) }
            if best == nil { best = (ip, mask) }
        }
        return best
    }

    static func text(_ ip: UInt32) -> String {
        "\(ip >> 24 & 0xFF).\(ip >> 16 & 0xFF).\(ip >> 8 & 0xFF).\(ip & 0xFF)"
    }

    /// Alle Adressen zum Durchsuchen (höchstens 254: bei größeren Netzen nur die eigene /24)
    static func candidates() -> [String] {
        guard let w = wifiAddress() else { return [] }
        let ip = w.ip
        let mask = max(w.mask, 0xFFFF_FF00)
        let net = ip & mask
        let broadcast = net | ~mask
        guard broadcast > net + 1 else { return [] }
        return ((net + 1)..<broadcast).filter { $0 != ip }.map(text)
    }

    /// Adressen mit offenem Port 6668 (parallel, je Versuch kurzes Zeitlimit)
    static func openHosts(_ hosts: [String], timeout: Double = 0.8, parallel: Int = 32) async -> [String] {
        var found: [String] = []
        var index = 0
        while index < hosts.count {
            let batch = Array(hosts[index..<min(index + parallel, hosts.count)])
            index += parallel
            await withTaskGroup(of: String?.self) { g in
                for h in batch { g.addTask { await isOpen(h, timeout: timeout) ? h : nil } }
                for await r in g { if let h = r { found.append(h) } }
            }
        }
        return found
    }

    static func isOpen(_ host: String, timeout: Double) async -> Bool {
        let c = NWConnection(host: NWEndpoint.Host(host), port: 6668, using: .tcp)
        let once = OnceFlag()
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            c.stateUpdateHandler = { state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        if !once.done { once.done = true; cont.resume(returning: true); c.cancel() }
                    case .failed, .waiting, .cancelled:
                        if !once.done { once.done = true; cont.resume(returning: false); c.cancel() }
                    default: break
                    }
                }
            }
            c.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !once.done { once.done = true; cont.resume(returning: false); c.cancel() }
            }
        }
    }
}
