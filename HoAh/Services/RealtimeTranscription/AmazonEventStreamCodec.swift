import Foundation

struct AmazonEventStreamMessage {
    let headers: [String: String]
    let payload: Data
}

enum AmazonEventStreamCodecError: LocalizedError {
    case invalidPrelude
    case invalidPreludeCRC
    case invalidMessageCRC
    case unsupportedHeaderType(UInt8)

    var errorDescription: String? {
        switch self {
        case .invalidPrelude:
            return "Invalid Amazon event stream frame."
        case .invalidPreludeCRC:
            return "Amazon event stream prelude CRC check failed."
        case .invalidMessageCRC:
            return "Amazon event stream message CRC check failed."
        case .unsupportedHeaderType(let type):
            return "Unsupported Amazon event stream header type: \(type)"
        }
    }
}

enum AmazonEventStreamCodec {
    static func encodeMessage(headers: [String: String], payload: Data) -> Data {
        let encodedHeaders = encodeHeaders(headers)
        let totalLength = 16 + encodedHeaders.count + payload.count

        var data = Data()
        data.appendUInt32(UInt32(totalLength))
        data.appendUInt32(UInt32(encodedHeaders.count))

        let preludeCRC = crc32(of: data)
        data.appendUInt32(preludeCRC)
        data.append(encodedHeaders)
        data.append(payload)
        data.appendUInt32(crc32(of: data))

        return data
    }

    static func decodeMessages(from buffer: inout Data) throws -> [AmazonEventStreamMessage] {
        var messages: [AmazonEventStreamMessage] = []

        while buffer.count >= 16 {
            let totalLength = try buffer.readUInt32(at: 0)
            let headersLength = try buffer.readUInt32(at: 4)

            guard totalLength >= 16, headersLength <= totalLength - 16 else {
                throw AmazonEventStreamCodecError.invalidPrelude
            }

            guard buffer.count >= Int(totalLength) else {
                break
            }

            let prelude = buffer.subdata(in: 0..<8)
            let expectedPreludeCRC = try buffer.readUInt32(at: 8)
            guard crc32(of: prelude) == expectedPreludeCRC else {
                throw AmazonEventStreamCodecError.invalidPreludeCRC
            }

            let messageData = buffer.subdata(in: 0..<Int(totalLength))
            let expectedMessageCRC = try messageData.readUInt32(at: Int(totalLength) - 4)
            let messageWithoutCRC = messageData.subdata(in: 0..<(Int(totalLength) - 4))
            guard crc32(of: messageWithoutCRC) == expectedMessageCRC else {
                throw AmazonEventStreamCodecError.invalidMessageCRC
            }

            let headersStart = 12
            let headersEnd = headersStart + Int(headersLength)
            let payloadEnd = Int(totalLength) - 4
            let headersData = messageData.subdata(in: headersStart..<headersEnd)
            let payload = messageData.subdata(in: headersEnd..<payloadEnd)

            messages.append(
                AmazonEventStreamMessage(
                    headers: try decodeHeaders(headersData),
                    payload: payload
                )
            )

            buffer.removeSubrange(0..<Int(totalLength))
        }

        return messages
    }

    private static func encodeHeaders(_ headers: [String: String]) -> Data {
        var data = Data()

        for key in headers.keys.sorted() {
            let value = headers[key] ?? ""
            let keyBytes = Data(key.utf8)
            let valueBytes = Data(value.utf8)

            data.append(UInt8(keyBytes.count))
            data.append(keyBytes)
            data.append(7) // string
            data.appendUInt16(UInt16(valueBytes.count))
            data.append(valueBytes)
        }

        return data
    }

    private static func decodeHeaders(_ data: Data) throws -> [String: String] {
        var headers: [String: String] = [:]
        var offset = 0

        while offset < data.count {
            let nameLength = Int(data[offset])
            offset += 1

            let nameEnd = offset + nameLength
            guard nameEnd <= data.count,
                  let name = String(data: data.subdata(in: offset..<nameEnd), encoding: .utf8) else {
                throw AmazonEventStreamCodecError.invalidPrelude
            }
            offset = nameEnd

            guard offset < data.count else {
                throw AmazonEventStreamCodecError.invalidPrelude
            }

            let valueType = data[offset]
            offset += 1

            guard valueType == 7 else {
                throw AmazonEventStreamCodecError.unsupportedHeaderType(valueType)
            }

            guard offset + 2 <= data.count else {
                throw AmazonEventStreamCodecError.invalidPrelude
            }
            let valueLength = Int(data.readUInt16Unchecked(at: offset))
            offset += 2

            let valueEnd = offset + valueLength
            guard valueEnd <= data.count,
                  let value = String(data: data.subdata(in: offset..<valueEnd), encoding: .utf8) else {
                throw AmazonEventStreamCodecError.invalidPrelude
            }
            offset = valueEnd

            headers[name] = value
        }

        return headers
    }

    private static func crc32(of data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crc32Table: [UInt32] = {
        (0..<256).map { value in
            var crc = UInt32(value)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB8_8320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    func readUInt32(at offset: Int) throws -> UInt32 {
        guard offset + 4 <= count else {
            throw AmazonEventStreamCodecError.invalidPrelude
        }
        return readUInt32Unchecked(at: offset)
    }

    func readUInt32Unchecked(at offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        return subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    func readUInt16Unchecked(at offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        return subdata(in: range).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
}
