import ChagokCore
import SwiftUI
import UserNotifications

struct ActivityEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State var activity: Activity
  var isNew: Bool
  @State private var thresholds = ["", "", ""]
  @State private var weeklyCount = "3"
  @State private var interval = "2"
  @State private var editing = false
  @State private var deleting = false
  private var canEdit: Bool { isNew || editing }
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
          Picker("아이콘 모양", selection: $activity.icon) {
            ForEach(
              [
                "leaf", "book", "figure.run", "pencil", "dumbbell", "fork.knife",
                "heart", "music.note", "cup.and.saucer", "drop", "moon", "sun.max",
                "figure.walk", "bicycle", "figure.yoga", "bed.double", "pills",
                "graduationcap", "laptopcomputer", "paintbrush", "camera", "globe",
                "house", "sparkles", "star", "pawprint", "gamecontroller", "hands.clap",
              ],
              id: \.self
            ) { icon in
              Image(systemName: icon).tag(icon).accessibilityLabel(icon)
            }
          }
          Text("아이콘 색상").font(.subheadline)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 12) {
            ForEach(Array(Palette.colorNames.enumerated()), id: \.element) { index, color in
              Button {
                activity.iconColor = color
              } label: {
                ActivityEmblem(icon: activity.icon, color: color)
                  .overlay(alignment: .bottomTrailing) {
                    if (activity.iconColor ?? "green") == color {
                      Image(systemName: "checkmark.circle.fill").font(.caption)
                        .foregroundStyle(.white, Palette.activityColor(color))
                    }
                  }
              }.buttonStyle(.plain)
                .accessibilityLabel(Palette.colorTitles[index])
                .accessibilityAddTraits((activity.iconColor ?? "green") == color ? .isSelected : [])
                .accessibilityIdentifier("icon-color-" + color)
            }
          }
          HStack {
            ActivityEmblem(icon: activity.icon, color: activity.iconColor)
            Text(activity.name.isEmpty ? "아이콘 미리보기" : activity.name)
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
            ForEach(0..<(activity.metric == .completion ? 1 : 3), id: \.self) { index in
              HStack {
                Text("\(index + 1)단계")
                UnitInput(
                  title: index == 0 ? "최소 기준" : "선택 입력",
                  text: $thresholds[index], unit: activity.metric.unit,
                  identifier: "threshold-\(index + 1)"
                ).disabled(activity.metric == .completion)
              }
            }
            Text(
              activity.metric == .completion
                ? "완료형은 한 번의 수행으로 달성해요. 여러 단계를 원하면 횟수를 선택하세요." : "1단계 필수 · 2·3단계 선택 · 작은 값부터 입력"
            )
            .font(.caption).foregroundStyle(.secondary)
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
              UnitInput(title: "주간 수행 일수", text: $weeklyCount, unit: "일/주", keyboard: .numberPad)
            }
            if rule?.schedule == .interval {
              UnitInput(title: "반복 간격", text: $interval, unit: "일", keyboard: .numberPad)
            }
            if !isNew {
              Text("변경은 다음 날부터 적용돼요. 주간 목표를 바꾸면 다음 월요일부터 적용돼요.").font(.caption).foregroundStyle(
                .secondary)
            }
          }
        }
        Section("활동 알림") {
          Toggle(
            "예정일에 알림",
            isOn: Binding(
              get: { activity.reminderMinute != nil },
              set: { activity.reminderMinute = $0 ? 540 : nil }))
          if activity.reminderMinute != nil {
            DatePicker(
              "알림 시각",
              selection: Binding(
                get: {
                  Calendar.current.startOfDay(for: .now).addingTimeInterval(
                    Double(activity.reminderMinute ?? 540) * 60)
                },
                set: {
                  let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                  activity.reminderMinute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
                }), displayedComponents: .hourAndMinute)
          }
          Text("전체 알림은 설정에서 켜고 끌 수 있어요. 주 N회는 월요일에 안내하며, 앱을 열 때 향후 28일의 가까운 알림부터 최대 60개를 갱신해요.")
            .font(.caption).foregroundStyle(.secondary)
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
          Text("편집 중 항목을 끌어서 순서를 바꿀 수 있어요.").font(.caption).foregroundStyle(.secondary)
        }
        if !isNew {
          Section {
            Button("활동 삭제", role: .destructive) { deleting = true }
          }
        }

      }.disabled(!canEdit).environment(\.editMode, .constant(canEdit ? .active : .inactive))
        .navigationTitle(isNew ? "활동 만들기" : "활동 설정").toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
          ToolbarItem(placement: .topBarTrailing) {
            if !canEdit { Button("편집") { editing = true } }
          }
          ToolbarItem(placement: .confirmationAction) {
            if canEdit { Button("저장", action: save).accessibilityIdentifier("activity-save") }
          }
        }.onAppear {
          if rule == nil {
            rule = activity.rules.last
            startDate = Day.date(rule!.start) ?? .now
            fillThresholds(rule!.thresholds)
            weeklyCount = String(rule!.weeklyCount)
            interval = String(rule!.interval)
          }
        }
        .onChange(of: activity.metric) { _, metric in
          fillThresholds(metric.defaults)
          activity.running = false
        }
        .alert("활동과 기록을 삭제할까요?", isPresented: $deleting) {
          Button("취소", role: .cancel) {}
          Button("삭제", role: .destructive) {
            if store.update({ state in
              state.entries.removeAll { $0.activityID == activity.id }
              state.activities.removeAll { $0.id == activity.id }
              if state.timer?.activityID == activity.id { state.timer = nil }
            }) {
              let id = activity.id
              Task {
                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                center.removePendingNotificationRequests(
                  withIdentifiers:
                    pending.filter { $0.identifier.hasPrefix(id + "|") }.map(\.identifier))
              }
              dismiss()
            }
          }
        } message: {
          Text("이 활동의 기록과 XP도 삭제되며 되돌릴 수 없어요. 책과 첨부 원본은 보존합니다. 기록을 남기려면 활동 보관을 사용하세요.")
        }
        .alert(
          "저장할 수 없어요",
          isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
          )
        ) {
          Button("확인") { failure = nil }
        } message: {
          Text(failure ?? "")
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
  private func fillThresholds(_ values: [Double]) {
    thresholds = (0..<3).map { index in
      guard index < values.count else { return "" }
      return String(format: "%g", activity.metric == .time ? values[index] / 60 : values[index])
    }
  }
  private func save() {
    do {
      guard var next = rule else { throw AppError.invalid("활동 설정을 준비 중이에요. 다시 저장해 주세요.") }
      let inputs = thresholds.map { $0.trimmingCharacters(in: .whitespaces) }
      guard !inputs[0].isEmpty, !(inputs[1].isEmpty && !inputs[2].isEmpty) else {
        throw AppError.invalid("1단계부터 순서대로 입력하세요.")
      }
      let parts = inputs.filter { !$0.isEmpty }.map { Double($0) }
      guard !parts.contains(where: { $0 == nil }) else { throw AppError.invalid("기준을 숫자로 입력하세요.") }
      next.thresholds = parts.compactMap { $0 }.map { activity.metric == .time ? $0 * 60 : $0 }
      if next.schedule == .weekly {
        guard let count = Int(weeklyCount), (1...7).contains(count) else {
          throw AppError.invalid("주간 일수는 1~7일로 입력하세요.")
        }
        next.weeklyCount = count
      }
      if next.schedule == .interval {
        guard let days = Int(interval), (1...365).contains(days) else {
          throw AppError.invalid("반복 간격은 1~365일로 입력하세요.")
        }
        next.interval = days
      }
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
        if activity.reminderMinute != nil {
          Task {
            do {
              let allowed = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound])
              if !allowed { store.error = "활동은 저장했지만 알림 권한이 꺼져 있어요. iPhone 설정에서 차곡 알림을 허용하세요." }
              store.refreshReminders()
            } catch { store.error = "알림 권한 확인 실패: \(error.localizedDescription)" }
          }
        }
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
