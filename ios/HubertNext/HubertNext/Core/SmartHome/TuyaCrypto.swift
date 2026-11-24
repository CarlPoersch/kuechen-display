import Foundation
import CryptoKit
import CommonCrypto

// ============================================================
// Krypto-Bausteine für das lokale Tuya-Protokoll (3.3 / 3.4 / 3.5).
// Vorbild ist tinytuya (Python), dort sind die Protokolle gut dokumentiert.
//   3.3: AES-128-ECB mit PKCS7, Prüfsumme CRC32
//   3.4: AES-128-ECB mit PKCS7, Prüfsumme HMAC-SHA256, Sitzungsschlüssel
//   3.5: AES-128-GCM (12 Byte IV, 16 Byte Tag), Sitzungsschlüssel
// ============================================================

enum TuyaCrypto {
    /// AES-128-ECB. `pad` = PKCS7 anhängen bzw. beim Entschlüsseln entfernen.
    static func ecb(_ data: Data, key: Data, encrypt: Bool, pad: Bool = true) -> Data? {
        guard key.count == kCCKeySizeAES128 else { return nil }
        if !encrypt && data.count % kCCBlockSizeAES128 != 0 { return nil }
        var out = Data(count: data.count + kCCBlockSizeAES128)
        let outCapacity = out.count
        var moved = 0
        let options = CCOptions(kCCOptionECBMode | (pad ? kCCOptionPKCS7Padding : 0))
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { o in
            data.withUnsafeBytes { d in
                key.withUnsafeBytes { k in
                    CCCrypt(CCOperation(encrypt ? kCCEncrypt : kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), options,
                            k.baseAddress, key.count, nil,
                            d.baseAddress, data.count,
                            o.baseAddress, outCapacity, &moved)
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return out.prefix(moved)
    }

    /// Entschlüsseln mit Polsterung; klappt das nicht (manche Geräte polstern nicht), ohne.
    static func ecbOpen(_ data: Data, key: Data) -> Data? {
        ecb(data, key: key, encrypt: false) ?? ecb(data, key: key, encrypt: false, pad: false)
    }

    /// AES-GCM verschlüsseln: liefert (Geheimtext, Tag)
    static func gcmSeal(_ plain: Data, key: Data, iv: Data, aad: Data) -> (Data, Data)? {
        guard let nonce = try? AES.GCM.Nonce(data: iv),
              let box = try? AES.GCM.seal(plain, using: SymmetricKey(data: key), nonce: nonce, authenticating: aad)
        else { return nil }
        return (box.ciphertext, box.tag)
    }

    /// AES-GCM entschlüsseln und prüfen
    static func gcmOpen(_ cipher: Data, key: Data, iv: Data, tag: Data, aad: Data) -> Data? {
        guard let nonce = try? AES.GCM.Nonce(data: iv),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag) else { return nil }
        return try? AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
    }

    static func hmac(_ data: Data, key: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hmacHexUpper(_ text: String, key: String) -> String {
        hmac(Data(text.utf8), key: Data(key.utf8)).map { String(format: "%02X", $0) }.joined()
    }

    static func random(_ n: Int) -> Data {
        var d = Data(count: n)
        _ = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, n, $0.baseAddress!) }
        return d
    }

    // CRC32 (wie zlib.crc32), Tabelle einmal berechnet
    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

extension Data {
    mutating func appendBE32(_ v: UInt32) { var b = v.bigEndian; Swift.withUnsafeBytes(of: &b) { append(contentsOf: $0) } }
    mutating func appendBE16(_ v: UInt16) { var b = v.bigEndian; Swift.withUnsafeBytes(of: &b) { append(contentsOf: $0) } }
    func be32(at i: Int) -> UInt32 {
        let s = startIndex + i
        return self[s..<s + 4].reduce(0) { ($0 << 8) | UInt32($1) }
    }
    /// Teilstück mit Index ab 0 (unabhängig vom startIndex)
    func tuyaSlice(_ from: Int, _ count: Int) -> Data { Data(self[(startIndex + from)..<(startIndex + from + count)]) }
    func tuyaSlice(from: Int) -> Data { Data(self[(startIndex + from)...]) }
}
