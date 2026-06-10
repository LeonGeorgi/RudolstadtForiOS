#if os(iOS)
import Foundation

func friendsLocalizedString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
#endif
