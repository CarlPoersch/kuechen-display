import Foundation
import Security

// ============================================================
// Eigenes Client-Zertifikat für die Android-TV-Fernbedienung.
// Der Fernseher merkt sich beim Koppeln dieses Zertifikat; danach
// erkennt er Hubert daran wieder. Schlüssel und Zertifikat bleiben
// im Schlüsselbund dieses Geräts (nie in der Cloud).
// iOS 15 kann keine Zertifikate erzeugen – deshalb ein kleiner
// DER-Baukasten (X.509 v3, RSA 2048, SHA-256), selbst signiert.
// ============================================================

enum ClientIdentity {
    private static let keyTag = Data("com.carlpoersch.hubert.atvremote.key".utf8)
    private static let certLabel = "Hubert Fernbedienung"

    /// Vorhandene Identität laden oder einmalig erzeugen
    static func get() throws -> SecIdentity {
        if let id = find() { return id }
        try create()
        guard let id = find() else { throw RemoteError.message("Zertifikat konnte nicht angelegt werden.") }
        return id
    }

    /// Öffentlicher Schlüssel als (Modulus, Exponent) – für den Kopplungs-Code
    static func publicNumbers(_ identity: SecIdentity) -> (Data, Data)? {
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        return cert.flatMap(RSAKey.numbers(of:))
    }

    // MARK: Schlüsselbund

    private static func find() -> SecIdentity? {
        let q: [String: Any] = [kSecClass as String: kSecClassIdentity, kSecReturnRef as String: true,
                                kSecMatchLimit as String: kSecMatchLimitAll]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let list = out as? [SecIdentity] else { return nil }
        for id in list {
            var cert: SecCertificate?
            SecIdentityCopyCertificate(id, &cert)
            if let c = cert, (SecCertificateCopySubjectSummary(c) as String?) == "atvremote" { return id }
        }
        return nil
    }

    private static func create() throws {
        // alte Reste entfernen
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: keyTag] as CFDictionary)
        SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certLabel] as CFDictionary)

        var err: Unmanaged<CFError>?
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: true, kSecAttrApplicationTag as String: keyTag,
                                            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly],
        ]
        guard let priv = SecKeyCreateRandomKey(attrs as CFDictionary, &err),
              let pub = SecKeyCopyPublicKey(priv),
              let pubDER = SecKeyCopyExternalRepresentation(pub, &err) as Data? else {
            throw RemoteError.message("Schlüssel konnte nicht erzeugt werden.")
        }
        let der = try X509.selfSigned(commonName: "atvremote", publicKeyPKCS1: pubDER) { tbs in
            guard let sig = SecKeyCreateSignature(priv, .rsaSignatureMessagePKCS1v15SHA256, tbs as CFData, &err) as Data? else {
                throw RemoteError.message("Zertifikat konnte nicht signiert werden.")
            }
            return sig
        }
        guard let cert = SecCertificateCreateWithData(nil, der as CFData) else {
            throw RemoteError.message("Zertifikat ist ungültig.")
        }
        let add: [String: Any] = [kSecClass as String: kSecClassCertificate, kSecValueRef as String: cert,
                                  kSecAttrLabel as String: certLabel,
                                  kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let s = SecItemAdd(add as CFDictionary, nil)
        guard s == errSecSuccess || s == errSecDuplicateItem else { throw RemoteError.message("Zertifikat nicht gespeichert (\(s)).") }
    }

    /// Neue Identität erzwingen (z. B. wenn der Fernseher sie nicht mehr annimmt)
    static func reset() {
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: keyTag] as CFDictionary)
        SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certLabel] as CFDictionary)
    }
}

// MARK: RSA-Zahlen aus Zertifikaten

enum RSAKey {
    /// Modulus und Exponent (ohne führende Nullen) aus einem Zertifikat
    static func numbers(of cert: SecCertificate) -> (Data, Data)? {
        var err: Unmanaged<CFError>?
        guard let key = SecCertificateCopyKey(cert),
              let der = SecKeyCopyExternalRepresentation(key, &err) as Data? else { return nil }
        return numbers(pkcs1: der)
    }

    /// RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
    static func numbers(pkcs1 der: Data) -> (Data, Data)? {
        var r = DERReader(der)
        guard let seq = r.read(tag: 0x30) else { return nil }
        var inner = DERReader(seq)
        guard let n = inner.read(tag: 0x02), let e = inner.read(tag: 0x02) else { return nil }
        return (n.drop { $0 == 0 }, e.drop { $0 == 0 })
    }
}

struct DERReader {
    private let b: [UInt8]
    private var i = 0
    init(_ d: Data) { b = [UInt8](d) }

    mutating func read(tag: UInt8) -> Data? {
        guard i + 2 <= b.count, b[i] == tag else { return nil }
        i += 1
        var len = Int(b[i]); i += 1
        if len & 0x80 != 0 {
            let n = len & 0x7F
            guard n <= 4, i + n <= b.count else { return nil }
            len = 0
            for _ in 0..<n { len = len << 8 | Int(b[i]); i += 1 }
        }
        guard i + len <= b.count else { return nil }
        defer { i += len }
        return Data(b[i ..< i + len])
    }
}

// MARK: X.509 bauen

enum X509 {
    static func tlv(_ tag: UInt8, _ content: Data) -> Data {
        var out = Data([tag])
        let n = content.count
        if n < 0x80 { out.append(UInt8(n)) }
        else {
            var len = [UInt8](); var v = n
            while v > 0 { len.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
            out.append(0x80 | UInt8(len.count)); out.append(contentsOf: len)
        }
        out.append(content)
        return out
    }

    static func seq(_ parts: Data...) -> Data { tlv(0x30, parts.reduce(Data(), +)) }

    static func oid(_ s: String) -> Data {
        let p = s.split(separator: ".").compactMap { UInt64($0) }
        var out = Data([UInt8(p[0] * 40 + p[1])])
        for v in p.dropFirst(2) {
            var bytes = [UInt8(v & 0x7F)]; var x = v >> 7
            while x > 0 { bytes.insert(UInt8(x & 0x7F) | 0x80, at: 0); x >>= 7 }
            out.append(contentsOf: bytes)
        }
        return tlv(0x06, out)
    }

    static func name(_ cn: String) -> Data {
        seq(tlv(0x31, seq(oid("2.5.4.3"), tlv(0x0C, Data(cn.utf8)))))
    }

    static func utcTime(_ d: Date) -> Data {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyMMddHHmmss'Z'"
        return tlv(0x17, Data(f.string(from: d).utf8))
    }

    /// Selbst signiertes Zertifikat (DER) für einen RSA-Schlüssel (PKCS#1)
    static func selfSigned(commonName: String, publicKeyPKCS1: Data, sign: (Data) throws -> Data) throws -> Data {
        let sha256RSA = seq(oid("1.2.840.113549.1.1.11"), Data([0x05, 0x00]))
        let rsaEnc = seq(oid("1.2.840.113549.1.1.1"), Data([0x05, 0x00]))
        let spki = seq(rsaEnc, tlv(0x03, Data([0x00]) + publicKeyPKCS1))
        let now = Date()
        let validity = seq(utcTime(now.addingTimeInterval(-86_400)), utcTime(now.addingTimeInterval(10 * 365 * 86_400)))
        let serial = tlv(0x02, Data([0x01] + (0..<7).map { _ in UInt8.random(in: 0...255) }))
        let version = tlv(0xA0, tlv(0x02, Data([0x02])))    // v3
        let tbs = seq(version, serial, sha256RSA, name(commonName), validity, name(commonName), spki)
        let sig = try sign(tbs)
        return seq(tbs, sha256RSA, tlv(0x03, Data([0x00]) + sig))
    }
}
