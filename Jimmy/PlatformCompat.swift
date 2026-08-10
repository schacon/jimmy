//
//  PlatformCompat.swift
//  Jimmy
//
//  Shims that let the iOS-first SwiftUI code compile unchanged on macOS.
//

import SwiftUI

extension Color {
  #if os(iOS)
    static let platformBackground = Color(.systemBackground)
    static let platformCardBackground = Color(.systemGray6)
    static let platformGray5 = Color(.systemGray5)
  #else
    static let platformBackground = Color(nsColor: .windowBackgroundColor)
    static let platformCardBackground = Color(nsColor: .controlBackgroundColor)
    static let platformGray5 = Color(nsColor: .quaternarySystemFill)
  #endif
}

#if os(macOS)
  /// Stand-in for UIKit's NavigationBarItem.TitleDisplayMode so existing
  /// `.navigationBarTitleDisplayMode(...)` call sites compile on macOS.
  enum PlatformTitleDisplayMode {
    case automatic
    case inline
    case large
  }

  extension View {
    /// No-op on macOS; title display modes are an iOS navigation bar concept.
    func navigationBarTitleDisplayMode(_ mode: PlatformTitleDisplayMode) -> some View {
      self
    }
  }

  extension ToolbarItemPlacement {
    static var navigationBarLeading: ToolbarItemPlacement { .navigation }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
  }

  /// Stand-in for UIKeyboardType; macOS has hardware keyboards only.
  enum PlatformKeyboardType {
    case `default`
    case decimalPad
    case numberPad
  }

  extension View {
    func keyboardType(_ type: PlatformKeyboardType) -> some View {
      self
    }
  }
#endif
