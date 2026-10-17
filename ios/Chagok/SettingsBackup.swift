import ChagokCore
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ImportButton: View {
  @Environment(AppStore.self) private var store
  @State private var picker = false
  @State private var preview: ImportPreview?
  @State private var showPreview = false
  @State private var loading = false
  var body: some View {
    Button {
      picker = true
    } label: {
      Label(loading ? "백업을 확인하고 있어요" : "백업 가져오기", systemImage: "square.and.arrow.down")
    }.disabled(loading)
      .fileImporter(
        isPresented: $picker, allowedContentTypes: [.json, .zip], allowsMultipleSelection: false
      ) { result in
        do {
          guard let url = try result.get().first else { return }
          let access = url.startAccessingSecurityScopedResource()
          defer { if access { url.stopAccessingSecurityScopedResource() } }
          let data = try Data(contentsOf: url)
          loading = true
          let current = store.state
          Task {
            do {
              preview = try await Task.detached { try Backup.preview(data, current: current) }.value
              showPreview = true
            } catch { store.error = error.localizedDescription }
            loading = false
          }
        } catch { store.error = error.localizedDescription }
      }.sheet(isPresented: $showPreview) { if let preview { ImportReview(preview: preview) } }
  }
}
struct ImportReview: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let preview: ImportPreview
  @State private var decisions: [String: Bool] = [:]
  var body: some View {
    NavigationStack {
      List {
        Section("가져오기 미리보기") {
          Text("활동 \(preview.state.activities.count)개 · 기록 \(preview.state.entries.count)개")
          Text(
            "이미지 \(preview.state.attachments.count)개 · 원문 \(preview.state.legacyEntities.count)개")
          Text("\(preview.legacy ? "기존 차곡 백업" : "iPhone 백업") · 동일 ID는 중복 생성하지 않습니다.")
        }
        if !preview.missing.isEmpty {
          Section("원본 없는 이미지 \(preview.missing.count)개") {
            Text("JSON에는 이미지가 포함되지 않아요. 현재 기기에 원본이 없다면 이미지 포함 ZIP으로 복원하세요.")
            ForEach(Array(preview.missing.enumerated()), id: \.offset) { Text($0.element) }
          }
        }
        if !preview.conflicts.isEmpty {
          Section("내용이 다른 항목 · 각각 선택하세요") {
            ForEach(preview.conflicts, id: \.self) { id in
              VStack(alignment: .leading) {
                Text(conflictName(id)).font(.headline)
                Text(conflictSummary(id)).font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("현재 내용 전체") {
                  Text(details(id, in: store.state)).font(.caption).textSelection(.enabled)
                }
                DisclosureGroup("백업 내용 전체") {
                  Text(details(id, in: preview.state)).font(.caption).textSelection(.enabled)
                }
                Picker(
                  "보존할 내용",
                  selection: Binding<Int>(
                    get: { decisions[id].map { $0 ? 2 : 1 } ?? 0 },
                    set: { decisions[id] = $0 == 0 ? nil : $0 == 2 })
                ) {
                  Text("선택 필요").tag(0)
                  Text("현재 기록").tag(1)
                  Text("백업 기록").tag(2)
                }
              }
            }
          }
        }
        Section("보존 안내") {
          Text("일치하는 기존 기록은 유지하고 새로운 기록만 추가합니다. 이전 기록의 XP는 자동 지급하지 않습니다. 원문과 지원하지 않는 상세 정보도 보존합니다.")
        }
      }.navigationTitle("백업 확인").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("가져오기") {
            if store.importBackup(preview, replace: Set(decisions.filter(\.value).map(\.key))) {
              dismiss()
            }
          }.disabled(preview.conflicts.contains(where: { decisions[$0] == nil }))
        }
      }
    }
  }
  private func details(_ id: String, in state: Snapshot) -> String {
    func json<T: Encodable>(_ item: T) -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return (try? encoder.encode(item)).map { String(decoding: $0, as: UTF8.self) } ?? "읽을 수 없는 내용"
    }
    if id.hasPrefix("legacy:") { return state.legacyEntities[String(id.dropFirst(7))] ?? "없음" }
    if let a = state.activities.first(where: { $0.id == id }) { return json(a) }
    if let e = state.entries.first(where: { $0.id == id }) { return json(e) }
    if let b = state.books.first(where: { $0.id == id }) { return json(b) }
    if let a = state.attachments.first(where: { $0.id == id }) { return json(a) }
    return "없음"
  }
  private func conflictName(_ id: String) -> String {
    preview.state.activities.first(where: { $0.id == id })?.name ?? preview.state.entries.first(
      where: { $0.id == id }).map { "\($0.date) · \($0.definition.name)" } ?? preview.state.books
      .first(where: { $0.id == id })?.title ?? preview.state.attachments.first(where: {
        $0.id == id
      })?.name ?? "이전 원문"
  }
  private func conflictSummary(_ id: String) -> String {
    if let incoming = preview.state.entries.first(where: { $0.id == id }),
      let old = store.state.entries.first(where: { $0.id == id })
    {
      return
        "현재: \(old.amount.map {old.definition.metric.display($0)} ?? "미상") · \(old.note)\n백업: \(incoming.amount.map {incoming.definition.metric.display($0)} ?? "미상") · \(incoming.note)"
    }
    return "현재 기기의 내용 또는 백업 내용을 선택하세요."
  }
}
struct SettingsView: View {
  @AppStorage("notificationsEnabled") private var notificationsEnabled = true
  @Environment(AppStore.self) private var store
  @State private var editor: Activity?
  @State private var exportURL: URL?
  @State private var exporting = false
  @State private var zone = ""
  @State private var retro = false
  @State private var retroFrom = Date()
  @State private var retroThrough = Date()
  @State private var retroConfirm = false
  @State private var archiveTarget: Activity?
  var body: some View {
    NavigationStack {
      List {
        Section("내 활동") {
          ForEach(store.state.activities) { a in
            HStack {
              Button {
                editor = a
              } label: {
                HStack {
                  ActivityEmblem(icon: a.icon, color: a.iconColor)
                  Text(a.name + (a.archived ? " · 보관됨" : ""))
                }
              }
              Spacer()
              Menu {
                Button("새 활동으로 복제") {
                  var copy = a
                  copy.id = UUID().uuidString
                  copy.name += " 복사"
                  copy.archived = false
                  var r = copy.rules.last!
                  r.effective = store.state.today()
                  r.start = r.effective
                  r.enabled = true
                  r.id = UUID().uuidString
                  copy.rules = [r]
                  editor = copy
                }
                Button(a.archived ? "다시 활성화" : "활동 보관") { archiveTarget = a }
              } label: {
                Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
              }.accessibilityLabel("\(a.name) 관리")
            }
          }
          Button("활동 만들기") {
            editor = Activity(name: "", metric: .completion, date: store.state.today())
          }
        }
        Section("백업 · 이 iPhone에 저장됨") {
          Text("기기 간 자동 동기화는 제공하지 않습니다. 중요한 기록은 파일 앱으로 백업하세요.").font(.footnote).foregroundStyle(
            .secondary)
          Button("JSON 내보내기") { export(false) }.disabled(exporting)
          Button("이미지 포함 ZIP 내보내기") { export(true) }.disabled(exporting)
          if let url = exportURL {
            ShareLink(item: url) { Label("파일에 저장 또는 공유", systemImage: "square.and.arrow.up") }
          }
          ImportButton()
          Text("기록 \(store.state.entries.count)개 · 이미지 \(store.state.attachments.count)개")
          NavigationLink("이미지 원본 관리") {
            List { AttachmentGallery(ids: store.state.attachments.map(\.id)) }.navigationTitle(
              "원본 이미지")
          }
          if !store.state.legacyEntities.isEmpty {
            NavigationLink("이전 차곡 원문 보관함") {
              List {
                ForEach(store.state.legacyEntities.keys.sorted(), id: \.self) { id in
                  DisclosureGroup(legacyTitle(store.state.legacyEntities[id] ?? "")) {
                    Text(store.state.legacyEntities[id] ?? "").font(.caption).textSelection(
                      .enabled)
                  }
                }
              }.navigationTitle("이전 원문")
            }
          }
        }
        Section("내 화면") {
          Toggle(
            "XP와 레벨 표시",
            isOn: Binding(
              get: { store.state.showRewards },
              set: { value in _ = store.update { $0.showRewards = value } }))
          Picker("시간대", selection: $zone) {
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
          }
          Button("다음 날부터 시간대 적용") {
            _ = store.update { s in
              let effective = Day.add(s.today(), 1)
              s.zoneChanges.removeAll { $0.effective >= effective }
              s.zoneChanges.append(ZoneChange(effective: effective, zone: zone))
            }
          }
          Text("현재 \(store.state.activeZone())\n여행 중에도 자동으로 바뀌지 않아요.").font(.caption)
            .foregroundStyle(.secondary)
        }
        Section("알림") {
          Toggle("전체 활동 알림", isOn: $notificationsEnabled)
            .onChange(of: notificationsEnabled) { _, _ in store.refreshReminders() }
          Text("활동별 알림 시각은 활동 편집 화면에서 설정해요. iPhone의 알림 권한도 허용되어 있어야 합니다.")
            .font(.caption).foregroundStyle(.secondary)
        }
        if store.state.entries.contains(where: { !$0.rewardEligible }) {
          Section("이전 기록 XP · 선택") {
            Toggle("소급 지급 미리보기", isOn: $retro)
            if retro {
              DatePicker("시작", selection: $retroFrom, displayedComponents: .date)
              DatePicker("종료", selection: $retroThrough, displayedComponents: .date)
              Text("실측값이 있는 기록만 당시 활동의 체크포인트로 계산합니다. 완료 확인이나 시간으로 페이지를 추정하지 않아요.").font(.caption)
              Text("추가 예상 \(retroXP) XP")
              Button("확인하고 적용") { retroConfirm = true }.disabled(retroXP == 0)
            }
          }
        }
        Section {
          Text("차곡 2.0 · 오프라인 전용").foregroundStyle(.secondary)
          Text("페이지·거리·시간·횟수·완료를 내 방식으로 기록하세요.").font(.footnote)
        }
      }.navigationTitle("설정").sheet(item: $editor) { selected in
        ActivityEditor(
          activity: selected,
          isNew: !store.state.activities.contains(where: { $0.id == selected.id }))
      }.onAppear { zone = store.state.activeZone() }
        .alert("이전 기록 XP를 적용할까요?", isPresented: $retroConfirm) {
          Button("취소", role: .cancel) {}
          Button("적용") {
            _ = store.update { applyRetro(&$0) }
            retro = false
          }
        } message: {
          Text("실측값을 기준으로 \(retroXP) XP가 추가됩니다. 반복 적용해도 중복 지급하지 않습니다.")
        }
        .alert(
          archiveTarget?.archived == true ? "활동을 다시 활성화할까요?" : "활동을 보관할까요?",
          isPresented: Binding(
            get: { archiveTarget != nil }, set: { if !$0 { archiveTarget = nil } })
        ) {
          Button("취소", role: .cancel) {}
          Button("적용") {
            if let a = archiveTarget {
              _ = store.update { s in
                guard let index = s.activities.firstIndex(where: { $0.id == a.id }),
                  var r = a.rules.last
                else { return }
                r.effective =
                  r.schedule == .weekly ? Day.add(Day.week(s.today()), 7) : Day.add(s.today(), 1)
                r.enabled = a.archived
                r.id = UUID().uuidString
                s.activities[index].rules.removeAll { $0.effective >= r.effective }
                s.activities[index].rules.append(r)
                s.activities[index].archived = !a.archived
              }
            }
            archiveTarget = nil
          }
        } message: {
          Text("기존 기록은 유지하고 일정 변경은 다음 적용일부터 반영합니다.")
        }
    }
  }
  private var retroXP: Int {
    var copy = store.state
    applyRetro(&copy)
    return Progress.totalXP(copy) - Progress.totalXP(store.state)
  }
  private func applyRetro(_ s: inout Snapshot) {
    let from = Day.string(retroFrom, zone: "UTC")
    let to = Day.string(retroThrough, zone: "UTC")
    for i in s.entries.indices
    where s.entries[i].date >= from && s.entries[i].date <= to && s.entries[i].amount != nil {
      s.entries[i].rewardEligible = true
    }
  }
  private func export(_ zip: Bool) {
    exporting = true
    defer { exporting = false }
    do { exportURL = try store.export(zip: zip) } catch { store.error = error.localizedDescription }
  }
  private func legacyTitle(_ raw: String) -> String {
    guard let d = raw.data(using: .utf8),
      let e = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    else { return "이전 원문" }
    return (e["name"] as? String) ?? (e["text"] as? String).map { String($0.prefix(35)) }
      ?? "\(e["type"] ?? "기록") · \(e["date"] ?? "")"
  }
}
