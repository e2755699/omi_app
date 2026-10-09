import SwiftUI
import WidgetKit

// Home screen widget: mirrors the Android CheerWidgetProvider. Data is written by Dart through
// home_widget (lib/data/home_widget_bridge.dart) into the shared App Group.
private let groupId = "group.com.jacklope.omiApp"
private let maxKeys = 8
private let checkinURL = URL(string: "omiapp://checkin?homeWidget")!

private extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
  static let ink = Color(hex: 0x1A1A1A)
  static let paper = Color(hex: 0xFFF8E6)
  static let tagYellow = Color(hex: 0xFFCC00)
}

struct KeyData: Identifiable {
  let index: Int
  let id: String
  let pillar: String
  let on: Bool
  let label: String
}

struct CheerEntry: TimelineEntry {
  let date: Date
  let dayText: String
  let cheersText: String
  let keysEnabled: Bool
  let message: String
  let footer: String
  let keys: [KeyData]
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> CheerEntry { load(preview: true) }

  func getSnapshot(in context: Context, completion: @escaping (CheerEntry) -> Void) {
    completion(load(preview: context.isPreview))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CheerEntry>) -> Void) {
    completion(Timeline(entries: [load(preview: false)], policy: .never))
  }

  private func load(preview: Bool) -> CheerEntry {
    let data = UserDefaults(suiteName: groupId)
    func str(_ key: String, _ fallback: String) -> String { data?.string(forKey: key) ?? fallback }
    if preview && data?.string(forKey: "day_text") == nil {
      return CheerEntry(
        date: Date(), dayText: "DAY 30/100", cheersText: "📣 3 人幫你加油", keysEnabled: true,
        message: "", footer: "今天 1/2 項 · ✏️ 寫 Reflect ›",
        keys: [
          KeyData(index: 0, id: "a", pillar: "move", on: true, label: "🏃\n✓運動"),
          KeyData(index: 1, id: "b", pillar: "learn", on: false, label: "📚\n學習"),
        ])
    }
    let count = min(Int(str("key_count", "0")) ?? 0, maxKeys)
    let keys = (0..<count).map { i in
      KeyData(
        index: i, id: str("key_\(i)_id", ""), pillar: str("key_\(i)_pillar", ""),
        on: str("key_\(i)_on", "0") == "1", label: str("key_\(i)_label", ""))
    }
    return CheerEntry(
      date: Date(), dayText: str("day_text", "100 DAYS"), cheersText: str("cheers_text", ""),
      keysEnabled: str("keys_enabled", "0") == "1", message: str("message_text", "打開 App 完成設定"),
      footer: str("footer_text", "打開 App ›"), keys: keys)
  }
}

private func litColors(_ pillar: String) -> (side: Color, top: Color) {
  switch pillar {
  case "nourish": return (Color(hex: 0x2F7A3A), Color(hex: 0x3FA34D))
  case "learn": return (Color(hex: 0x2B64BF), Color(hex: 0x3A86FF))
  case "recover": return (Color(hex: 0x6845B8), Color(hex: 0x8B5CF6))
  default: return (Color(hex: 0xB57704), Color(hex: 0xF29F05))
  }
}

// Pixel-style keycap: black outline, thicker bottom edge when raised, pressed down when done.
struct KeycapFace: View {
  let key: KeyData

  var body: some View {
    let colors = key.on
      ? litColors(key.pillar) : (side: Color(hex: 0xBDB49C), top: Color(hex: 0xFFFBF0))
    ZStack {
      Rectangle().fill(Color.ink)
      Rectangle().fill(colors.side).padding(.horizontal, 2).padding(.bottom, 2)
        .padding(.top, key.on ? 3 : 0)
      Rectangle().fill(colors.top).padding(.horizontal, 4)
        .padding(.top, key.on ? 4 : 3).padding(.bottom, key.on ? 4 : 7)
      Text(key.label)
        .font(.system(size: 11, weight: .bold)).multilineTextAlignment(.center)
        .lineLimit(3).minimumScaleFactor(0.6)
        .foregroundColor(key.on ? .paper : .ink)
        .padding(.horizontal, 4).padding(.top, key.on ? 6 : 2).padding(.bottom, key.on ? 3 : 6)
    }
  }
}

struct KeycapView: View {
  let key: KeyData

  var body: some View {
    if let url = URL(string: "omiapp://toggle?item=\(key.id)") {
      Button(intent: ToggleIntent(url: url, appGroup: groupId)) { KeycapFace(key: key) }
        .buttonStyle(.plain)
    }
  }
}

struct CheerWidgetView: View {
  let entry: CheerEntry

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(entry.dayText).font(.system(size: 12, weight: .bold, design: .monospaced))
          .foregroundColor(.tagYellow)
        Spacer(minLength: 4)
        Text(entry.cheersText).font(.system(size: 12, weight: .bold)).foregroundColor(.paper)
      }
      .lineLimit(1).padding(.horizontal, 8).padding(.vertical, 3).background(Color.ink)

      if entry.keysEnabled {
        let rows = [Array(entry.keys.prefix(4)), Array(entry.keys.dropFirst(4))]
        VStack(spacing: 3) {
          ForEach(0..<2, id: \.self) { r in
            HStack(spacing: 3) {
              ForEach(0..<4, id: \.self) { c in
                if c < rows[r].count {
                  KeycapView(key: rows[r][c])
                } else {
                  Color.clear
                }
              }
            }
          }
        }
        .padding(3).frame(maxHeight: .infinity)
      } else {
        Text(entry.message).font(.system(size: 14, weight: .bold)).foregroundColor(.ink)
          .multilineTextAlignment(.center).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      Text(entry.footer).font(.system(size: 11, weight: .bold)).foregroundColor(.ink)
        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.bottom, 3)
    }
    .overlay(Rectangle().stroke(Color.ink, lineWidth: 3))
    .widgetURL(checkinURL)
  }
}

struct CheerWidget: Widget {
  // Must match iOSName in lib/data/home_widget_bridge.dart.
  let kind = "CheerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      CheerWidgetView(entry: entry)
        .containerBackground(Color.paper, for: .widget)
    }
    .configurationDisplayName("Omi 打卡")
    .description("看今天幾個人幫你加油，直接按鍵帽打卡。")
    .supportedFamilies([.systemMedium])
    .contentMarginsDisabled()
  }
}

@main
struct CheerWidgetBundle: WidgetBundle {
  var body: some Widget { CheerWidget() }
}
