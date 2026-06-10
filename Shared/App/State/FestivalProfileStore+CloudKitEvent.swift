#if os(iOS)
import CloudKit

extension CKSyncEngine.Event {
    var logDescription: String {
        switch self {
        case .stateUpdate:
            return "stateUpdate"
        case .accountChange:
            return "accountChange"
        case .fetchedDatabaseChanges:
            return "fetchedDatabaseChanges"
        case .fetchedRecordZoneChanges:
            return "fetchedRecordZoneChanges"
        case .sentRecordZoneChanges:
            return "sentRecordZoneChanges"
        case .sentDatabaseChanges:
            return "sentDatabaseChanges"
        case .didFetchChanges:
            return "didFetchChanges"
        case .willFetchChanges:
            return "willFetchChanges"
        case .willFetchRecordZoneChanges:
            return "willFetchRecordZoneChanges"
        case .didFetchRecordZoneChanges:
            return "didFetchRecordZoneChanges"
        case .willSendChanges:
            return "willSendChanges"
        case .didSendChanges:
            return "didSendChanges"
        @unknown default:
            return "unknown"
        }
    }
}
#endif
