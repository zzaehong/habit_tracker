import ChagokCore
import SwiftUI

struct ActivityEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State var activity: Activity
  var isNew: Bool
  @State private var thresholds = ""
  @State private var rule: Rule?
  @State private var startDate = Date()
  @State private var field: CustomField?
  @State private var failure: String?
  private var hasEntries: Bool { store.state.entries.contains { $0.activityID == activity.id } }
  var body: some View {
    NavigationStack {
      Form {
        Section("1 · 내 활동") {
          TextField("활동 이름", text: $activity.name).accessibilityIdentifier("activity-name")
          Picker("아이콘", selection: $activity.icon) {
            ForEach(
              [
                "leaf", "book", "figure.run", "pencil", "dumbbell", "fork.knife", "heart",
                "music.note",
              ], id: \.self
            ) { Image(systemName: $0).tag($0) }
          }
        }
        Section("2 · 무엇을 측정할까요?") {
          Picker("측정 방식", selection: $activity.metric) {
            ForEach(Metric.allCases, id: \.self) { Text($0.title).tag($0) }
          }.disabled(hasEntries)
          if hasEntries {
            Text("기록이 있는 활동의 측정 방식은 유지합니다. 설정에서 새 활동으로 복제할 수 있어요.").font(.caption).foregroundStyle(
              .secondary)
          }
        }
        if rule != nil {
          Section("3 · 작은 실천의 기준") {
            TextField("체크포인트 (예: 5, 15, 30)", text: $thresholds).keyboardType(
              .numbersAndPunctuation
            ).accessibilityIdentifier("thresholds")
            Text("단위: \(activity.metric.unit) · 최대 3개, 작은 값부터 쉼표로 구분").font(.caption)
              .foregroundStyle(.secondary)
          }
          Section("4 · 나에게 맞는 일정") {
            Picker("반복", selection: Binding(get: { rule!.schedule }, set: { rule!.schedule = $0 }))
            { ForEach(ScheduleKind.allCases, id: \.self) { Text($0.title).tag($0) } }
            DatePicker("시작일", selection: $startDate, displayedComponents: .date).environment(
              \.timeZone, TimeZone(secondsFromGMT: 0)!)
            if rule?.schedule == .weekdays {
              ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) {
                index, title in
                Toggle(
                  title,
                  isOn: Binding(
                    get: { rule!.weekdays.contains(index + 1) },
                    set: {
                      if $0 {
                        rule!.weekdays.append(index + 1)
                      } else {
                        rule!.weekdays.removeAll { $0 == index + 1 }
                      }
                    }))
              }
            }
            if rule?.schedule == .weekly {
              Stepper(
                "주 \(rule!.weeklyCount)일",
                value: Binding(get: { rule!.weeklyCount }, set: { rule!.weeklyCount = $0 }),
                in: 1...7)
            }
            if rule?.schedule == .interval {
              Stepper(
                "\(rule!.interval)일 간격",
                value: Binding(get: { rule!.interval }, set: { rule!.interval = $0 }), in: 1...365)
            }
            if !isNew {
              Text("변경은 다음 날부터 적용돼요. 주간 목표를 바꾸면 다음 월요일부터 적용돼요.").font(.caption).foregroundStyle(
                .secondary)
            }
          }
        }
        Section("더 남기고 싶은 내용 · 선택") {
          ForEach(activity.fields) { f in
            Button {
              field = f
            } label: {
              HStack {
                Text(f.name)
                Spacer()
                Text(f.hidden ? "숨김" : f.unit).foregroundStyle(.secondary)
              }
            }
          }
          .onMove { activity.fields.move(fromOffsets: $0, toOffset: $1) }
          Button("추가 항목 만들기") { field = CustomField(name: "", kind: .text) }
          Text("항목 순서는 편집 버튼으로 바꿀 수 있어요.").font(.caption).foregroundStyle(.secondary)
        }
        if let failure { Text(failure).foregroundStyle(.red) }
      }.navigationTitle(isNew ? "활동 만들기" : "활동 설정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .topBarTrailing) { EditButton() }
        ToolbarItem(placement: .confirmationAction) {
          Button("저장", action: save).accessibilityIdentifier("activity-save")
        }
      }.onAppear {
        if rule == nil {
          rule = activity.rules.last
          startDate = Day.date(rule!.start) ?? .now
          thresholds =
            activity.metric == .time
            ? rule!.thresholds.map { String($0 / 60) }.joined(separator: ", ")
            : rule!.thresholds.map { String(format: "%g", $0) }.joined(separator: ", ")
        }
      }
      .onChange(of: activity.metric) { _, metric in
        thresholds = metric.defaults.map { String(format: "%g", metric == .time ? $0 / 60 : $0) }
          .joined(separator: ", ")
        activity.running = false
      }
      .sheet(item: $field) { f in
        FieldEditor(
          field: f, locked: hasEntries && activity.fields.contains(where: { $0.id == f.id })
        ) { saved in
          if let i = activity.fields.firstIndex(where: { $0.id == saved.id }) {
            activity.fields[i] = saved
          } else {
            activity.fields.append(saved)
          }
        }
      }
    }
  }
  private func save() {
    do {
      guard var next = rule else { return }
      let parts = thresholds.split(separator: ",", omittingEmptySubsequences: false).map {
        Double($0.trimmingCharacters(in: .whitespaces))
      }
      guard !parts.contains(where: { $0 == nil }) else { throw AppError.invalid("기준을 숫자로 입력하세요.") }
      next.thresholds = parts.compactMap { $0 }.map { activity.metric == .time ? $0 * 60 : $0 }
      next.start = Day.string(startDate, zone: "UTC")
      let today = store.state.today()
      if isNew {
        next.effective = today
        activity.rules = [next]
      } else {
        let old = activity.rule(on: today)
        next.effective =
          old?.schedule == .weekly || next.schedule == .weekly
          ? Day.add(Day.week(today), 7) : Day.add(today, 1)
        next.id = UUID().uuidString
        activity.rules.removeAll { $0.effective >= next.effective }
        activity.rules.append(next)
      }
      try activity.validate()
      if store.update({ s in
        if let i = s.activities.firstIndex(where: { $0.id == activity.id }) {
          s.activities[i] = activity
        } else {
          s.activities.append(activity)
        }
      }) {
        dismiss()
      }
    } catch { failure = error.localizedDescription }
  }
}
struct FieldEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State var field: CustomField
  let locked: Bool
  var save: (CustomField) -> Void
  @State private var options = ""
  var body: some View {
    NavigationStack {
      Form {
        TextField("항목 이름", text: $field.name)
        Picker("종류", selection: $field.kind) {
          Text("숫자").tag(FieldKind.number)
          Text("텍스트").tag(FieldKind.text)
          Text("단일 선택").tag(FieldKind.choice)
        }.disabled(locked)
        if field.kind == .number {
          TextField("단위", text: $field.unit).disabled(locked)
          Picker("집계", selection: $field.aggregate) {
            Text("합계").tag(Aggregate.sum)
            Text("평균").tag(Aggregate.mean)
          }
        }
        if field.kind == .choice { TextField("선택지 (쉼표로 구분)", text: $options).disabled(locked) }
        Toggle("항목 숨기기", isOn: $field.hidden)
        if locked { Text("의미·단위·선택지를 바꾸려면 이 항목을 숨기고 새 항목을 만드세요.").font(.footnote) }
      }.navigationTitle("추가 항목").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("완료") {
            field.options = options.split(separator: ",").map {
              $0.trimmingCharacters(in: .whitespaces)
            }
            save(field)
            dismiss()
          }.disabled(
            field.name.trimmingCharacters(in: .whitespaces).isEmpty
              || (field.kind == .choice && options.isEmpty))
        }
      }.onAppear { options = field.options.joined(separator: ", ") }
    }
  }
}
