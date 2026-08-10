//
//  CloudSyncMonitor.swift
//  Jimmy
//

import CloudKit
import CoreData
import Foundation

/// Observes the CloudKit sync events emitted by SwiftData's underlying
/// NSPersistentCloudKitContainer and exposes sync status for the Settings UI.
///
/// SwiftData exports every saved mutation to iCloud automatically in the
/// background; this class only reports on that activity, it does not drive it.
@Observable
@MainActor
final class CloudSyncMonitor {
  enum Status {
    case localOnly
    case accountUnavailable
    case syncing
    case waiting
    case synced
    case failed(String)
  }

  let isCloudSyncEnabled: Bool
  private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
  private(set) var lastSyncDate: Date?
  private(set) var lastErrorMessage: String?
  private var activeEventIDs: Set<UUID> = []

  private static let lastSyncDateKey = "lastCloudSyncDate"
  private static let containerIdentifier = "iCloud.com.chacons.Jimmy"

  var status: Status {
    guard isCloudSyncEnabled else { return .localOnly }
    switch accountStatus {
    case .available, .couldNotDetermine:
      break
    default:
      return .accountUnavailable
    }
    if !activeEventIDs.isEmpty { return .syncing }
    if let lastErrorMessage { return .failed(lastErrorMessage) }
    return lastSyncDate == nil ? .waiting : .synced
  }

  init(isCloudSyncEnabled: Bool) {
    self.isCloudSyncEnabled = isCloudSyncEnabled
    self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date

    guard isCloudSyncEnabled else { return }

    NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let event = notification.userInfo?[
          NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
          as? NSPersistentCloudKitContainer.Event
      else { return }
      let identifier = event.identifier
      let endDate = event.endDate
      let succeeded = event.succeeded
      let errorMessage = event.error?.localizedDescription
      MainActor.assumeIsolated {
        self?.handleEvent(
          identifier: identifier,
          endDate: endDate,
          succeeded: succeeded,
          errorMessage: errorMessage
        )
      }
    }

    NotificationCenter.default.addObserver(
      forName: .CKAccountChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.refreshAccountStatus()
      }
    }

    Task { await self.refreshAccountStatus() }
  }

  func refreshAccountStatus() async {
    guard isCloudSyncEnabled else { return }
    let container = CKContainer(identifier: Self.containerIdentifier)
    accountStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
  }

  private func handleEvent(
    identifier: UUID, endDate: Date?, succeeded: Bool, errorMessage: String?
  ) {
    // Each sync event is posted twice: once when it starts (endDate == nil)
    // and once when it finishes.
    guard let endDate else {
      activeEventIDs.insert(identifier)
      return
    }
    activeEventIDs.remove(identifier)
    if succeeded {
      lastSyncDate = endDate
      lastErrorMessage = nil
      UserDefaults.standard.set(endDate, forKey: Self.lastSyncDateKey)
    } else if let errorMessage {
      lastErrorMessage = errorMessage
    }
  }
}
