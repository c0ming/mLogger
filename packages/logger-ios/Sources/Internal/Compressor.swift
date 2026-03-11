import Foundation

protocol Compressor {
    var algorithm: String { get }
    func compress(_ input: Data) throws -> Data
}

struct NoopCompressor: Compressor {
    let algorithm = "none"

    func compress(_ input: Data) throws -> Data {
        input
    }
}

struct ZlibCompressor: Compressor {
    let algorithm = "zlib"

    func compress(_ input: Data) throws -> Data {
        if #available(macOS 10.15, iOS 13.0, *) {
            return try (input as NSData).compressed(using: .zlib) as Data
        }
        return input
    }
}
