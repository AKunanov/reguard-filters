// Compiles every rule file in dist/ the way Safari does, so a list Safari would reject never ships.
//
//     swift verify.swift dist

import CryptoKit
import Foundation
import WebKit

let dist = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: dist.appendingPathComponent("manifest.json"))) as! [String: Any]
let store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("reguard-verify-\(UUID())"))!
var failed = false

for file in manifest["files"] as! [[String: Any]] {
    let name = file["name"] as! String
    let json = try (Data(contentsOf: dist.appendingPathComponent(name)) as NSData).decompressed(using: .zlib) as Data
    guard SHA256.hash(data: json).map({ String(format: "%02x", $0) }).joined() == file["sha256"] as! String else {
        print("\(name): checksum mismatch")
        failed = true
        continue
    }

    var error: Error?
    var done = false
    store.compileContentRuleList(forIdentifier: name, encodedContentRuleList: String(decoding: json, as: UTF8.self)) { _, compileError in
        error = compileError
        done = true
    }
    while !done {
        RunLoop.main.run(until: Date() + 0.05)
    }
    print("\(name): \(error.map { "rejected by WebKit: \($0.localizedDescription)" } ?? "compiles")")
    failed = failed || error != nil
}

exit(failed ? 1 : 0)
