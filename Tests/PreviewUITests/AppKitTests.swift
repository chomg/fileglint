import Testing

/// AppKit has one application/window/focus environment per test process.
/// Serialize the native UI suites together, not merely within each suite.
@Suite(.serialized)
struct AppKitTests {}
