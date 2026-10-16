import ChagokCore
import SwiftData
import SwiftUI

@main struct ChagokApp: App {
  private let container: ModelContainer?
  private let startupError: String?
  init() {
    do {
      let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
      var config = ModelConfiguration(
        "Chagok", isStoredInMemoryOnly: testing, cloudKitDatabase: .none)
      #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--test-store"),
          ProcessInfo.processInfo.arguments.count > index + 1,
          let id = UUID(uuidString: ProcessInfo.processInfo.arguments[index + 1])
        {
          let url = URL.applicationSupportDirectory.appending(path: "test-\(id.uuidString).store")
          config = ModelConfiguration("UITest", url: url, cloudKitDatabase: .none)
        }
      #endif
      container = try ModelContainer(for: StoredSnapshot.self, configurations: config)
      startupError = nil
    } catch {
      container = nil
      startupError = error.localizedDescription
    }
  }
  var body: some Scene {
    WindowGroup {
      if let container {
        RootHost(context: container.mainContext)
      } else {
        ContentUnavailableView(
          "저장소를 열 수 없어요", systemImage: "externaldrive.badge.exclamationmark",
          description: Text(startupError ?? "앱을 다시 열어 주세요. 데이터는 자동 삭제하지 않습니다."))
      }
    }
  }
}
struct RootHost: View {
  @State private var store: AppStore
  init(context: ModelContext) { _store = State(initialValue: AppStore(context: context)) }
  var body: some View {
    RootView().modifier(TestAppearance()).environment(store)
      .environment(\.timeZone, TimeZone(identifier: store.state.activeZone()) ?? .current)
      .tint(Palette.green).buttonBorderShape(.roundedRectangle(radius: 14)).alert(
        "확인해 주세요",
        isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
      ) {
        Button("확인") { store.error = nil }
      } message: {
        Text(store.error ?? "")
      }
  }
}
enum Palette {
  static let green = Color("AccentColor")
  static let gold = Color("RewardColor")
  static let background = Color("BackgroundColor")
}
extension View {
  func card() -> some View {
    padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
      .overlay {
        RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.green.opacity(0.09), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.025), radius: 12, y: 4)
  }
}
struct ActivityEmblem: View {
  let icon: String
  var body: some View {
    Image(systemName: icon).font(.title3.weight(.semibold))
      .foregroundStyle(Palette.green).frame(width: 44, height: 44)
      .background(Palette.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
      .accessibilityHidden(true)
  }
}

struct RootView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    if !store.loaded {
      ContentUnavailableView(
        "기록을 안전하게 보관 중입니다", systemImage: "externaldrive",
        description: Text("저장소를 열지 못했습니다. 앱을 다시 실행해 주세요."))
    } else if !store.state.onboarded {
      OnboardingView()
    } else {
      TabView {
        TodayView().tabItem { Label("오늘", systemImage: "sun.max") }
        HistoryView().tabItem { Label("기록", systemImage: "book.closed") }
        GrowthView().tabItem { Label("성장", systemImage: "chart.bar") }
        SettingsView().tabItem { Label("설정", systemImage: "slider.horizontal.3") }
      }
    }
  }
}
struct OnboardingView: View {
  @Environment(AppStore.self) private var store
  @State private var editor: Activity?
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Image(systemName: "leaf.fill").font(.system(size: 46)).foregroundStyle(Palette.green)
            .padding(24).background(
              Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 30)
            )
            .accessibilityHidden(true)
          Text("작은 실천을,\n차곡차곡.").font(.largeTitle.bold())
          Text("내 방식으로 활동을 만들고\n쌓여 가는 변화를 만나세요.").font(.title3).foregroundStyle(.secondary)
          Text("먼저 하나만 골라도 좋아요").font(.headline)
          template("독서", subtitle: "시간 대신 읽은 페이지로", metric: .pages, icon: "book")
          template("러닝", subtitle: "나만의 거리와 페이스", metric: .distance, icon: "figure.run")
          Button {
            editor = Activity(name: "", metric: .completion, date: store.state.today())
          } label: {
            Label("직접 만들기", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
          }.buttonStyle(.bordered)
          if !store.state.activities.isEmpty {
            ForEach(store.state.activities) { a in Label(a.name, systemImage: a.icon) }
            Button("차곡 시작하기") { _ = store.update { $0.onboarded = true } }.buttonStyle(
              .borderedProminent
            ).accessibilityIdentifier("onboarding-finish")
          }
          ImportButton()
          Text("계정 없이 시작해요. 기록은 이 iPhone에 저장되며 백업으로 옮길 수 있어요.").font(.footnote).foregroundStyle(
            .secondary)
        }.padding(24)
      }.background(Palette.background).sheet(item: $editor) {
        ActivityEditor(activity: $0, isNew: true)
      }
    }
  }
  private func template(_ title: String, subtitle: String, metric: Metric, icon: String)
    -> some View
  {
    Button {
      var a = Activity(name: title, metric: metric, date: store.state.today())
      a.icon = icon
      a.running = metric == .distance
      editor = a
    } label: {
      HStack {
        ActivityEmblem(icon: icon)
        VStack(alignment: .leading) {
          Text(title).font(.headline)
          Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
      }.card()
    }.buttonStyle(.plain).accessibilityIdentifier("template-\(metric.rawValue)")
  }
}

private struct TestAppearance: ViewModifier {
  func body(content: Content) -> some View {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--large-text-dark") {
        content.dynamicTypeSize(.accessibility3).preferredColorScheme(.dark)
      } else {
        content
      }
    #else
      content
    #endif
  }
}
