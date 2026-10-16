import ChagokCore
import SwiftUI

struct RecordRoute: Identifiable {
  let id = UUID()
  var activity: Activity
  var entry: Entry?
  var day: String
}
struct TodayView: View {
  @Environment(AppStore.self) private var store
  @State private var date = Date()
  @State private var route: RecordRoute?
  @State private var undoID: String?
  @State private var adding = false
  private var day: String { Day.string(date, zone: store.state.activeZone()) }
  private var active: [Activity] {
    store.state.activities.filter { $0.rule(on: day)?.enabled == true }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          DatePicker("활동 날짜", selection: $date, in: ...Date(), displayedComponents: .date)
            .datePickerStyle(.compact)
          Text("오늘의 작은 실천").font(.system(.largeTitle, design: .rounded, weight: .bold))
          Text("완벽하지 않아도 괜찮아요. 한 번의 실천부터.").foregroundStyle(.secondary)
          if store.state.showRewards {
            let earned = store.state.activities.reduce(0) {
              $0 + Progress.daily($1, day, store.state.entries, rewardOnly: true).xp
            }
            let level = Progress.level(Progress.totalXP(store.state))
            VStack(alignment: .leading, spacing: 8) {
              ViewThatFits(in: .horizontal) {
                HStack {
                  Text("\(day == store.state.today() ? "오늘" : "선택한 날") \(earned) XP")
                    .accessibilityIdentifier("daily-xp")
                  Spacer()
                  Text("레벨 \(level.level)")
                }
                VStack(alignment: .leading) {
                  Text("\(day == store.state.today() ? "오늘" : "선택한 날") \(earned) XP")
                  Text("레벨 \(level.level)")
                }
              }.font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(
                Palette.green)
              ProgressView(value: Double(level.earned), total: Double(level.required))
                .tint(Palette.gold).accessibilityLabel("레벨 진행")
              Text("다음 레벨까지 \(level.required - level.earned) XP")
                .font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
              .background(
                LinearGradient(
                  colors: [Palette.green.opacity(0.12), Palette.gold.opacity(0.08)],
                  startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24))
          }
          if store.state.timer != nil { TimerCard() }
          if active.isEmpty {
            ContentUnavailableView(
              "첫 활동을 만들어 보세요", systemImage: "leaf",
              description: Text("페이지, 거리, 시간, 횟수 중 내 기준을 선택해요."))
            Button("활동 만들기") { adding = true }.buttonStyle(.borderedProminent)
          }
          let daily = active.filter {
            (Progress.due($0, day) || overdue($0)) && $0.rule(on: day)?.schedule != .weekly
          }
          let weekly = active.filter {
            Progress.due($0, day) && $0.rule(on: day)?.schedule == .weekly
          }
          let pending = daily.filter { !Progress.daily($0, day, store.state.entries).satisfied }
          let complete = daily.filter { Progress.daily($0, day, store.state.entries).satisfied }
          if !daily.isEmpty { Text("\(complete.count)개 달성 · \(pending.count)개 남음").font(.headline) }
          ForEach(pending) { activityCard($0) }
          if !weekly.isEmpty {
            Text("이번 주 자유롭게").font(.headline)
            ForEach(weekly) { activityCard($0) }
          }
          if !complete.isEmpty {
            Text("차곡 쌓았어요").font(.headline)
            ForEach(complete) { activityCard($0) }
          }
          let other = active.filter { !Progress.due($0, day) && !overdue($0) }
          if !other.isEmpty {
            DisclosureGroup("다른 활동도 기록하기") {
              ForEach(other) { a in
                Button(a.name) { route = RecordRoute(activity: a, day: day) }.frame(minHeight: 44)
              }
            }
          }
          if let undoID {
            HStack {
              Text("기기에 저장했어요")
              Spacer()
              Button("실행 취소") {
                store.remove(undoID)
                self.undoID = nil
              }
            }.font(.subheadline).card()
          }
        }.padding()
      }.background(Palette.background).navigationTitle("차곡").toolbar {
        Button {
          adding = true
        } label: {
          Image(systemName: "plus")
        }.accessibilityLabel("활동 추가")
      }.sheet(item: $route) { EntryEditor(activity: $0.activity, entry: $0.entry, day: $0.day) }
        .sheet(isPresented: $adding) {
          ActivityEditor(
            activity: Activity(name: "", metric: .completion, date: store.state.today()),
            isNew: true)
        }
    }
  }
  private func overdue(_ activity: Activity) -> Bool {
    guard let rule = activity.rule(on: day), rule.schedule == .once, rule.enabled, rule.start < day
    else { return false }
    return !Set(
      store.state.entries.filter {
        $0.activityID == activity.id && $0.date >= rule.start && $0.date <= day
      }.map(\.date)
    ).contains { Progress.daily(activity, $0, store.state.entries).satisfied }
  }
  private func activityCard(_ a: Activity) -> some View {
    let progress = Progress.daily(a, day, store.state.entries)
    let rule = a.rule(on: day)
    return VStack(alignment: .leading, spacing: 14) {
      HStack {
        ActivityEmblem(icon: a.icon)
        Text(a.name).font(.title3.bold())
        Spacer()
        if progress.satisfied {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
            .accessibilityLabel("최소 달성")
        }
      }
      if let amount = progress.amount {
        Text("오늘 \(a.metric.display(amount))\(a.metric.unit)").font(.title3.bold())
      } else {
        Text(progress.satisfied ? "최소 달성 확인 · 수치 미기록" : "작은 실천부터 시작해요").foregroundStyle(.secondary)
      }
      if let thresholds = rule?.thresholds, !thresholds.isEmpty {
        HStack(spacing: 6) {
          ForEach(Array(thresholds.enumerated()), id: \.offset) { index, _ in
            Capsule().fill(index < progress.stages ? Palette.green : Palette.green.opacity(0.12))
              .frame(height: 6)
          }
        }.accessibilityElement(children: .ignore)
          .accessibilityLabel("체크포인트 \(progress.stages)/\(thresholds.count)단계 달성")
      }
      if let next = rule?.thresholds.dropFirst(progress.stages).first {
        Text("다음 체크포인트 \(a.metric.display(next))\(a.metric.unit)").font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if overdue(a) {
        Text("밀린 일정 · 예정일 \(rule?.start ?? day)").font(.caption).foregroundStyle(.secondary)
      }
      if rule?.schedule == .weekly {
        let count = Day.range(Day.week(day), Day.add(Day.week(day), 6)).filter {
          Progress.daily(a, $0, store.state.entries).satisfied
        }.count
        Text("이번 주 \(count)/\(rule?.weeklyCount ?? 3)일").font(.subheadline)
      }
      ViewThatFits(in: .horizontal) {
        actions(a, progress: progress, vertical: false)
        actions(a, progress: progress, vertical: true)
      }
    }.card()
  }
  @ViewBuilder private func actions(_ a: Activity, progress: DailyProgress, vertical: Bool)
    -> some View
  {
    let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
    layout {
      Button {
        if a.metric == .time && store.state.timer == nil {
          _ = store.update { $0.timer = TimerState(activityID: a.id, date: day) }
        } else {
          let quick = store.state.entries.first {
            $0.activityID == a.id && $0.date == day && $0.confirmedMinimum && $0.amount == nil
          }
          route = RecordRoute(activity: a, entry: quick, day: day)
        }
      } label: {
        Text(
          a.metric == .pages
            ? "페이지 기록" : a.metric == .time && store.state.timer == nil ? "타이머 시작" : "기록하기"
        ).frame(minHeight: 30)
      }.buttonStyle(.borderedProminent).accessibilityIdentifier("record-\(a.metric.rawValue)")
      if !progress.satisfied {
        Button("최소 \(a.metric.display(a.rule(on:day)?.thresholds.first ?? 1))\(a.metric.unit) 달성") {
          undoID = store.quick(a, day: day)
        }.buttonStyle(.bordered).frame(minHeight: 44)
      } else {
        Button("추가 기록") { route = RecordRoute(activity: a, day: day) }.frame(minHeight: 44)
      }
    }
  }
}
struct TimerCard: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    if let timer = store.state.timer,
      let a = store.state.activities.first(where: { $0.id == timer.activityID })
    {
      VStack(alignment: .leading, spacing: 12) {
        Text(a.name).font(.headline)
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text(
            Duration.seconds(timer.elapsed(at: context.date)).formatted(
              .time(pattern: .minuteSecond))
          ).font(.largeTitle.monospacedDigit()).accessibilityLabel("진행 시간")
        }
        HStack {
          Button(timer.startedAt == nil ? "계속" : "일시정지") {
            _ = store.update {
              if $0.timer?.startedAt == nil {
                $0.timer?.resume(at: .now)
              } else {
                $0.timer?.pause(at: .now)
              }
            }
          }
          Spacer()
          Button("기록하고 종료") {
            var entry = Entry(activity: a, date: timer.date, timezone: store.state.activeZone())
            entry.amount = timer.elapsed(at: .now)
            entry.seconds = entry.amount
            _ = store.update {
              $0.entries.append(entry)
              $0.timer = nil
            }
          }.buttonStyle(.borderedProminent)
        }
      }.card()
    }
  }
}
