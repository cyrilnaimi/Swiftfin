//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation

@MainActor
final class KeychainObservable<Value: Storable>: ObservableObject, _StoredValueObservable {

    private var onObjectChanged: (() -> Void)?

    let key: StoredValues.Key<Value>

    init(_ key: StoredValues.Key<Value>, onObjectChanged: (() -> Void)? = nil) {
        self.key = key
        self.onObjectChanged = onObjectChanged
    }

    var value: Value {
        get {
            StoredValues[key]
        }
        set {
            onObjectChanged?()
            StoredValues[key] = newValue
        }
    }

    // The keychain has no change-notification stream, so there is nothing to
    // observe. Keychain-backed values are read via the `StoredValues`
    // subscript rather than through live `@StoredValue` updates.
    func observe() {}
}
