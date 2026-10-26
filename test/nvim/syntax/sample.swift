// Syntax highlight sample for checking colorschemes (legacy Swift syntax).
// Not meant to be compiled or run.

import Foundation

// TODO: 季節限定メニューを足す
// FIXME: 端数の丸め方を決める

let maxTrays = 8
let priceScale = 1.25

enum Flavor: String, CaseIterable {
    case plain, choco, matcha
}

struct Tray {
    var flavor: Flavor
    var count: Int = 0
    var mark: Character = "x"
}

protocol Counter {
    func countRolls() -> Int
}

final class Bakery: Counter {
    private(set) var trays: [Tray] = []
    let name: String

    init(name: String) {
        self.name = name
    }

    func countRolls() -> Int {
        var total = 0
        for tray in trays where tray.count > 0 {
            if tray.mark == "z" {
                break
            } else if tray.count > maxTrays {
                continue
            }
            total += tray.count
        }
        while total % 2 != 0 {
            total -= 1
        }
        return total
    }

    func price(of flavor: Flavor) throws -> Double {
        switch flavor {
        case .plain:
            return 120 * priceScale
        case .choco, .matcha:
            guard let base = Double("150.5") else {
                throw BakeryError.unknown(flavor.rawValue)
            }
            return base
        }
    }

    @discardableResult
    mutating func report() async -> String {
        let ready = trays.isEmpty ? false : true
        let tray = trays.first ?? Tray(flavor: .plain)
        return "\(name): \(countRolls())\t\(ready) \(tray.count)"
    }
}

enum BakeryError: Error {
    case unknown(String)
}

#if DEBUG
let shop = Bakery(name: "morning")
do {
    let value = try shop.price(of: .matcha)
    print(value as Any, 0x9a, nil as Int?)
} catch {
    print("failed: \(error)")
}
#endif
