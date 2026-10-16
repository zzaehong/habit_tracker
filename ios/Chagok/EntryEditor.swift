import ChagokCore
import PhotosUI
import SwiftUI
import Vision

struct EntryEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let activity: Activity
  let original: Entry?
  @State private var entry: Entry
  @State private var amount = ""
  @State private var start = ""
  @State private var last = ""
  @State private var minutes = ""
  @State private var duration = ""
  @State private var intensity = ""
  @State private var heart = ""
  @State private var cadence = ""
  @State private var bookTitle = ""
  @State private var date: Date
  @State private var failure: String?
  @State private var confirming = false
  @State private var deleting = false
  @State private var pending: Entry?
  @State private var photos: [PhotosPickerItem] = []
  @State private var analyzing = false
  @State private var questions: [String] = []
  @State private var candidate: RunningCandidate?
  @State private var initialized = false
  init(activity: Activity, entry: Entry?, day: String) {
    self.activity = activity
    self.original = entry
    _entry = State(
      initialValue: entry
        ?? Entry(activity: activity, date: day, timezone: TimeZone.current.identifier))
    _date = State(initialValue: Day.date(day) ?? .now)
  }
  var body: some View {
    NavigationStack {
      Form {
        Section(activity.name) {
          DatePicker("활동 날짜", selection: $date, in: ...Date(), displayedComponents: .date)
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
          if entry.confirmedMinimum {
            Label("최소 달성 확인 · 측정값 미입력", systemImage: "checkmark.circle").font(.subheadline)
          }
          if activity.metric == .pages {
            readingFields
          } else if activity.metric == .completion {
            Toggle("수행 완료", isOn: $entry.confirmedMinimum)
          } else {
            UnitInput(
              title: activity.metric.title, text: $amount, unit: activity.metric.unit,
              identifier: "entry-amount")
          }
        }
        if activity.running {
          runningFields
        } else if activity.metric == .pages {
          Section("선택 기록") { UnitInput(title: "읽은 시간", text: $minutes, unit: "분") }
        }
        if !entry.definition.fields.filter({ !$0.hidden }).isEmpty {
          Section("추가 기록 · 선택") {
            ForEach(entry.definition.fields.filter { !$0.hidden }) { f in
              if f.kind == .choice {
                Picker(f.name, selection: fieldBinding(f)) {
                  Text("미입력").tag("")
                  ForEach(f.options, id: \.self) { Text($0).tag($0) }
                }
              } else {
                UnitInput(
                  title: f.name, text: fieldBinding(f), unit: f.unit,
                  keyboard: f.kind == .number ? .numbersAndPunctuation : .default)
              }
            }
          }
        }
        Section("메모") {
          TextField("남기고 싶은 이야기", text: $entry.note, axis: .vertical).lineLimit(3...8)
        }
        if !entry.attachments.isEmpty {
          Section("원본 이미지") { AttachmentGallery(ids: entry.attachments, allowDelete: false) }
        }
        if let raw = entry.legacyJSON {
          DisclosureGroup("이전 차곡 상세 기록") {
            Text(legacyDescription(raw)).font(.footnote).textSelection(.enabled)
          }
        }
        if original != nil {
          Section {
            Button("기록 삭제", role: .destructive) { deleting = true }
          }
        }
        if let failure {
          Text(failure).foregroundStyle(.red).accessibilityIdentifier("entry-error")
        }
      }.navigationTitle(original == nil ? "기록하기" : "기록 수정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("저장") { prepareSave() }.disabled(analyzing).accessibilityIdentifier("entry-save")
        }
      }.onAppear(perform: initialize)
        .alert("입력한 수치로 달성 상태를 수정할까요?", isPresented: $confirming) {
          Button("취소", role: .cancel) {}
          Button("수치로 수정") {
            if var e = pending {
              e.confirmedMinimum = false
              commit(e)
            }
          }
        } message: {
          Text("최소 기준보다 작은 수치예요. XP와 실행률도 다시 계산됩니다.")
        }
        .alert("기록을 삭제할까요?", isPresented: $deleting) {
          Button("취소", role: .cancel) {}
          Button("삭제", role: .destructive) {
            if store.update({ $0.entries.removeAll { $0.id == entry.id } }) { dismiss() }
          }
        } message: {
          Text("이 기록의 XP와 성장 지표도 다시 계산됩니다. 첨부 원본은 보존합니다.")
        }
        .onChange(of: photos) { _, items in Task { await analyze(items) } }
    }
  }
  private var readingFields: some View {
    Group {
      Picker(
        "책",
        selection: Binding(
          get: { entry.bookID ?? "" },
          set: { id in
            entry.bookID = id.isEmpty ? nil : id
            if let id = entry.bookID {
              let position = Progress.bookPosition(
                id, entries: store.state.entries.filter { $0.id != entry.id })
              start = position.last.map(String.init) ?? ""
              bookTitle = ""
            }
            last = ""
          })
      ) {
        Text("새 책 또는 선택 안 함").tag("")
        ForEach(store.state.books) { Text($0.title).tag($0.id) }
      }
      if entry.bookID == nil {
        TextField("새 책 제목 · 선택", text: $bookTitle).accessibilityIdentifier("book-title")
      }
      Picker("페이지 입력", selection: $entry.readingMode) {
        Text("읽은 분량").tag("direct")
        Text("시작·마지막 페이지").tag("range")
      }.pickerStyle(.segmented)
      if entry.readingMode == "direct" {
        UnitInput(
          title: "읽은 페이지 수", text: $amount, unit: "쪽", keyboard: .numberPad,
          identifier: "entry-amount")
      } else {
        UnitInput(
          title: "시작 페이지 · 선택", text: $start, unit: "쪽", keyboard: .numberPad,
          identifier: "start-page")
        UnitInput(
          title: "마지막 페이지", text: $last, unit: "쪽", keyboard: .numberPad, identifier: "last-page")
        Text("55 − 40 = 15쪽. 다시 읽기는 시작 위치를 바꿔 새 구간으로 남겨요.").font(.caption).foregroundStyle(
          .secondary)
      }
      if let id = entry.bookID,
        let furthest = Progress.bookPosition(id, entries: store.state.entries).furthest
      {
        Text("가장 멀리 읽은 위치: \(furthest)쪽").font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private var runningFields: some View {
    Section("러닝 상세 · 선택") {
      UnitInput(
        title: "분:초 또는 시:분:초", text: $duration, unit: "시간", keyboard: .numbersAndPunctuation)
      UnitInput(title: "체감 강도 1–10", text: $intensity, unit: "점")
      UnitInput(title: "평균 심박수", text: $heart, unit: "bpm", keyboard: .numberPad)
      UnitInput(title: "평균 케이던스", text: $cadence, unit: "steps/min", keyboard: .numberPad)
      if let km = Double(amount), km > 0, let seconds = parseDuration(duration) {
        Text("평균 페이스 \(Duration.seconds(seconds/km).formatted(.time(pattern:.minuteSecond)))/km")
      }
      PhotosPicker(selection: $photos, maxSelectionCount: 5, matching: .images) {
        Label("NRC 캡처 분석 · 최대 5장", systemImage: "photo.on.rectangle")
      }.disabled(analyzing)
      if analyzing { ProgressView("기기에서 글자를 읽고 있어요") }
      ForEach(Array(questions.enumerated()), id: \.offset) {
        Text($0.element).font(.footnote).foregroundStyle(.secondary)
      }
      if let candidate {
        VStack(alignment: .leading, spacing: 8) {
          Text("추출값 확인").font(.headline)
          Text(
            "거리: \(candidate.distance.map {String(format:"%.2f km",$0)} ?? "미상") · 시간: \(candidate.seconds.map {Duration.seconds($0).formatted(.time(pattern:.minuteSecond))} ?? "미상")"
          )
          Button("확인한 값을 입력에 반영") {
            if let v = candidate.distance { amount = String(v) }
            if let v = candidate.seconds {
              duration = String(format: "%d:%02d", Int(v) / 60, Int(v) % 60)
            }
            if let v = candidate.heartRate { heart = String(v) }
            if let v = candidate.cadence { cadence = String(v) }
            entry.reportedPace = candidate.reportedPace
            entry.ocrText = candidate.raw
            self.candidate = nil
          }
          DisclosureGroup("OCR 원문") { Text(candidate.raw).font(.caption).textSelection(.enabled) }
        }
      }
    }
  }
  private func fieldBinding(_ f: CustomField) -> Binding<String> {
    Binding(get: { entry.fields[f.id] ?? "" }, set: { entry.fields[f.id] = $0 })
  }
  private func initialize() {
    guard !initialized else { return }
    initialized = true
    if original == nil {
      entry.timezone = store.state.activeZone()
      if activity.metric == .pages,
        let recent = store.state.entries.last(where: {
          $0.activityID == activity.id && $0.bookID != nil
        })
      {
        entry.bookID = recent.bookID
        entry.readingMode = "range"
        start =
          Progress.bookPosition(recent.bookID!, entries: store.state.entries).last.map(String.init)
          ?? ""
      }
    }
    amount =
      entry.amount.map { String(format: "%g", activity.metric == .time ? $0 / 60 : $0) } ?? ""
    if let value = entry.startPage { start = String(value) }
    last = entry.lastPage.map(String.init) ?? ""
    minutes = entry.seconds.map { String(format: "%g", $0 / 60) } ?? ""
    duration = entry.seconds.map { String(format: "%d:%02d", Int($0) / 60, Int($0) % 60) } ?? ""
    intensity = entry.intensity.map { String(format: "%g", $0) } ?? ""
    heart = entry.heartRate.map { String(format: "%g", $0) } ?? ""
    cadence = entry.cadence.map { String(format: "%g", $0) } ?? ""
  }
  private func number(_ text: String, _ label: String) throws -> Double? {
    if text.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
    guard let n = Double(text.replacingOccurrences(of: ",", with: ".")), n.isFinite, n >= 0 else {
      throw AppError.invalid("\(label)을 확인하세요.")
    }
    return n
  }
  private func page(_ text: String) throws -> Int? {
    guard !text.isEmpty else { return nil }
    guard let n = Int(text), n >= 0 else { throw AppError.invalid("페이지는 0 이상의 정수입니다.") }
    return n
  }
  private func prepareSave() {
    do {
      var e = entry
      e.date = Day.string(date, zone: "UTC")
      e.ruleID = activity.rule(on: e.date)?.id
      if activity.metric == .pages && e.readingMode == "range" {
        e.startPage = try page(start)
        e.lastPage = try page(last)
        if let start = e.startPage, let end = e.lastPage {
          guard end >= start else { throw AppError.invalid("다시 읽기는 시작 페이지를 새로 지정하세요.") }
          e.amount = Double(end - start)
        } else {
          e.amount = nil
        }
      } else if activity.metric != .completion {
        e.amount = try number(amount, "측정값").map { activity.metric == .time ? $0 * 60 : $0 }
        e.startPage = nil
        e.lastPage = nil
      }
      if activity.metric == .time { e.seconds = e.amount }
      if activity.metric == .pages { e.seconds = try number(minutes, "시간").map { $0 * 60 } }
      if activity.running {
        e.seconds = parseDuration(duration)
        if !duration.isEmpty && e.seconds == nil {
          throw AppError.invalid("시간은 분:초 또는 시:분:초로 입력하세요.")
        }
        e.intensity = try number(intensity, "강도")
        e.heartRate = try number(heart, "심박수")
        e.cadence = try number(cadence, "케이던스")
      }
      try e.validate()
      if e.confirmedMinimum, let amount = e.amount,
        amount < (activity.rule(on: e.date)?.thresholds.first ?? 1)
      {
        pending = e
        confirming = true
      } else {
        commit(e)
      }
    } catch { failure = error.localizedDescription }
  }
  private func commit(_ value: Entry) {
    var e = value
    var book: Book?
    if activity.metric == .pages, e.bookID == nil,
      !bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
    {
      book = Book(title: bookTitle)
      e.bookID = book!.id
    }
    if store.save(e, book: book) { dismiss() }
  }
  private func analyze(_ items: [PhotosPickerItem]) async {
    guard !items.isEmpty else { return }
    analyzing = true
    defer { analyzing = false }
    do {
      var results: [RunningCandidate] = []
      var inputs: [(Data, String, String)] = []
      for (index, item) in items.enumerated() {
        guard let data = try await item.loadTransferable(type: Data.self),
          data.count <= 10 * 1024 * 1024
        else { throw AppError.invalid("이미지는 장당 10MB까지입니다.") }
        let png = data.starts(with: [137, 80, 78, 71])
        let jpeg = data.starts(with: [255, 216, 255])
        guard png || jpeg else { throw AppError.invalid("PNG 또는 JPEG 캡처를 선택하세요.") }
        let hash = Archive.hash(data)
        if store.state.attachments.contains(where: { $0.hash == hash }) {
          questions.append("이미 저장된 이미지입니다. 원본을 재사용합니다.")
        }
        inputs.append((data, "캡처 \(index+1)", png ? "image/png" : "image/jpeg"))
        results.append(
          try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            try VNImageRequestHandler(data: data).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
              .joined(separator: "\n")
            return RunningOCR.parse(text)
          }.value)
      }
      let attachments = try store.addImages(inputs)
      entry.attachments = Array(Set(entry.attachments + attachments.map(\.id)))
      let merged = RunningOCR.merge(results)
      candidate = merged
      questions += merged.questions
      if let km = merged.distance,
        store.state.entries.contains(where: {
          $0.activityID == activity.id && $0.date == entry.date
            && abs(($0.amount ?? -100) - km) < 0.01
        })
      {
        questions.append("같은 날짜·거리의 기록이 있습니다. 중복 여부를 확인하세요.")
      }
    } catch { failure = error.localizedDescription }
  }
}
func parseDuration(_ text: String) -> Double? {
  let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { Double($0) }
  guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 && $0!.isFinite }),
    parts.dropFirst().allSatisfy({ $0! < 60 })
  else { return nil }
  return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
}
func legacyDescription(_ raw: String) -> String {
  guard let data = raw.data(using: .utf8),
    let entity = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let fields = entity["data"] as? [String: Any]
  else { return raw }
  let labels = [
    "sets": "세트", "exercise": "운동", "kg": "무게 kg", "reps": "횟수", "mealStatus": "식사 상태",
    "menu": "메뉴", "kcal": "열량 kcal", "carbs": "탄수화물 g", "protein": "단백질 g", "fat": "지방 g",
    "alias": "대상 별칭", "subject": "과목", "plannedSeconds": "예정 시간 (초)", "seconds": "시간 (초)",
    "note": "메모", "slot": "끼니", "mealTime": "식사 시각",
  ]
  return fields.keys.sorted().map { "\(labels[$0] ?? $0): \(fields[$0]!)" }.joined(separator: "\n")
}
struct AttachmentGallery: View {
  @Environment(AppStore.self) private var store
  let ids: [String]
  var allowDelete = true
  @State private var deleting: String?
  var body: some View {
    ForEach(ids, id: \.self) { id in
      if let a = store.state.attachments.first(where: { $0.id == id }) {
        VStack {
          if let data = store.image(a.hash), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().accessibilityLabel(a.name)
          } else {
            Label("원본 없음 · ZIP 백업에서 복원하세요", systemImage: "photo.badge.exclamationmark")
          }
          if allowDelete { Button("원본 이미지 삭제", role: .destructive) { deleting = id } }
        }
      }
    }.alert(
      "원본 이미지를 삭제할까요?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("취소", role: .cancel) {}
      Button("삭제", role: .destructive) {
        if let id = deleting { store.deleteAttachment(id) }
        deleting = nil
      }
    } message: {
      Text("이 이미지를 사용하는 기록에서도 첨부가 제거됩니다.")
    }
  }
}
