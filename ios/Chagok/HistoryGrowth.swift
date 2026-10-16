import ChagokCore
import Charts
import SwiftUI

struct HistoryView: View {
  @Environment(AppStore.self) private var store
  @State private var filter = ""
  @State private var date = Date()
  @State private var allDates = true
  @State private var route: RecordRoute?
  @State private var deleting: String?
  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("활동", selection: $filter) {
            Text("모든 활동").tag("")
            ForEach(store.state.activities) { Text($0.name).tag($0.id) }
          }
          Toggle("모든 날짜", isOn: $allDates)
          if !allDates { DatePicker("날짜", selection: $date, displayedComponents: .date) }
        }
        let entries = store.state.entries.filter {
          (filter.isEmpty || $0.activityID == filter)
            && (allDates || $0.date == Day.string(date, zone: store.state.activeZone()))
        }.sorted { $0.date > $1.date }
        if entries.isEmpty {
          ContentUnavailableView(
            "아직 기록이 없어요", systemImage: "book.closed", description: Text("오늘 화면에서 작은 실천을 남겨 보세요."))
        }
        ForEach(entries) { e in
          Button {
            if let a = store.state.activities.first(where: { $0.id == e.activityID }) {
              route = RecordRoute(activity: a, entry: e, day: e.date)
            }
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                ActivityEmblem(icon: e.definition.icon)
                Text(e.definition.name).font(.headline)
                Spacer()
                Text(e.date).font(.caption).foregroundStyle(.secondary)
              }
              if let amount = e.amount {
                Text("\(e.definition.metric.display(amount))\(e.definition.metric.unit)")
              } else {
                Text(
                  e.confirmedMinimum
                    ? "최소 달성 · 수치 미기록" : e.legacyDone == true ? "이전 완료 기록" : "수치 미기록"
                ).foregroundStyle(.secondary)
              }
              if let rule = e.definition.rule(on: e.date), rule.schedule == .once,
                e.date > rule.start
              {
                Text("지연 완료 · 예정일 \(rule.start)").font(.caption).foregroundStyle(.secondary)
              }
              if !e.note.isEmpty {
                Text(e.note).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)
              }
            }
          }.buttonStyle(.plain).swipeActions {
            Button("삭제", role: .destructive) { deleting = e.id }
          }
        }
      }.scrollContentBackground(.hidden).background(Palette.background).navigationTitle("기록").sheet(
        item: $route
      ) {
        EntryEditor(activity: $0.activity, entry: $0.entry, day: $0.day)
      }.alert(
        "기록을 삭제할까요?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
      ) {
        Button("취소", role: .cancel) {}
        Button("삭제", role: .destructive) {
          if let deleting { store.remove(deleting) }
          deleting = nil
        }
      } message: {
        Text("이 기록의 XP와 행동 통계도 다시 계산됩니다.")
      }
    }
  }
}
struct GrowthView: View {
  @Environment(AppStore.self) private var store
  @State private var period = 7
  @State private var from = Calendar.current.date(byAdding: .day, value: -6, to: .now)!
  @State private var through = Date()
  private var today: String { store.state.today() }
  private var end: String {
    period == 0 ? min(Day.string(through, zone: store.state.activeZone()), today) : today
  }
  private var start: String {
    period == 0 ? Day.string(from, zone: store.state.activeZone()) : Day.add(today, -period + 1)
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("실천이 쌓인 모습").font(.system(.largeTitle, design: .rounded, weight: .bold))
          Picker("기간", selection: $period) {
            Text("7일").tag(7)
            Text("28일").tag(28)
            Text("직접 선택").tag(0)
          }.pickerStyle(.segmented)
          if period == 0 {
            DatePicker("시작", selection: $from, displayedComponents: .date)
            DatePicker("종료", selection: $through, displayedComponents: .date)
          }
          Text("\(start) — \(end) · 오늘의 미완료는 실패로 계산하지 않아요.").font(.caption).foregroundStyle(
            .secondary)
          if start > end { Text("종료일을 시작일 이후로 선택하세요.").foregroundStyle(.red) }
          if store.state.activities.isEmpty {
            ContentUnavailableView(
              "나만의 변화를 기다리고 있어요", systemImage: "chart.bar",
              description: Text("활동을 만들고 첫 기록을 남겨 보세요."))
          }
          VStack(alignment: .leading, spacing: 10) {
            Label("측정 가능한 성장", systemImage: "chart.xyaxis.line").font(.headline)
            Text("얼마나 했는지, 계획을 얼마나 실천했는지, 얼마나 이어 왔는지 살펴봐요.")
              .font(.subheadline).foregroundStyle(.secondary)
            DisclosureGroup("지표 계산 기준") {
              VStack(alignment: .leading, spacing: 10) {
                Text("활동량 · 직접 기록한 페이지·거리·시간 등의 합계와 평균이에요. 수치 없는 빠른 완료는 포함하지 않아요.")
                Text("실행률 · 확정된 예정 기회 중 최소 기준을 달성한 비율이에요. 아직 끝나지 않은 오늘·이번 주의 미완료는 제외해요.")
                Text("지속력 · 예정된 날에 연속 성공한 횟수예요. 쉬는 날은 끊기지 않으며, 주 N회 활동은 연속 달성 주 수를 사용해요.")
                Text("기간 변화 · 바로 앞의 같은 길이 기간과 기록된 활동량을 비교해요. 기록이 없으면 0으로 추정하지 않아요.")
                Text("빠른 완료는 실행률·지속력에 반영해요. XP는 별도의 게임 보상이며 능력이나 성과 점수가 아니에요.")
              }.font(.caption).padding(.top, 8)
            }
          }.card()
          if start <= end {
            ForEach(store.state.activities) { a in activityGrowth(a) }
          }
          if store.state.showRewards {
            let xp = Progress.totalXP(store.state)
            let level = Progress.level(xp)
            VStack(alignment: .leading, spacing: 12) {
              Label("작은 보상", systemImage: "sparkles").foregroundStyle(Palette.gold)
              Text("레벨 \(level.level)").font(.system(.largeTitle, design: .rounded, weight: .bold))
              Text("누적 \(xp) XP")
              ProgressView(value: Double(level.earned), total: Double(level.required)).tint(
                Palette.gold)
              Text("다음 레벨까지 \(level.required-level.earned) XP").font(.caption)
              Text("XP는 게임 보상이며 실제 능력 점수가 아니에요.").font(.caption).foregroundStyle(.secondary)
            }.card()
          }
        }.padding()
      }.background(Palette.background).navigationTitle("성장")
    }
  }
  private func activityGrowth(_ a: Activity) -> some View {
    let entries = store.state.entries.filter {
      $0.activityID == a.id && $0.date >= start && $0.date <= end
    }
    let values = entries.compactMap(\.amount)
    let total = values.reduce(0, +)
    let stats = Progress.practice(
      a, entries: store.state.entries, from: start, through: end, today: today)
    let allTime = Progress.practice(
      a, entries: store.state.entries, from: a.rules.map(\.effective).min() ?? start,
      through: today, today: today)
    let length = max(0, Day.distance(start, end) + 1)
    let previous = store.state.entries.filter {
      $0.activityID == a.id && $0.date >= Day.add(start, -length) && $0.date < start
    }.compactMap(\.amount)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        ActivityEmblem(icon: a.icon)
        Text(a.name).font(.title3.bold())
      }
      Text("활동량").font(.subheadline.bold()).foregroundStyle(Palette.green)
      Text(values.isEmpty ? "측정값 없음" : "\(a.metric.display(total))\(a.metric.unit) 쌓았어요").font(
        .title2.bold())
      if !values.isEmpty {
        Text("기록당 평균 \(a.metric.display(total/Double(values.count)))\(a.metric.unit)").font(
          .subheadline
        ).foregroundStyle(.secondary)
      }
      Divider()
      Text("실행률").font(.subheadline.bold()).foregroundStyle(Palette.green)
      Text(
        "실행률 \(stats.rate.map {String(format:"%.0f%%",$0*100)} ?? "해당 없음") · \(stats.achieved)/\(stats.expected) 확정 기회"
      ).font(.subheadline)
      if a.rule(on: today)?.schedule != .once {
        Text("지속력").font(.subheadline.bold()).foregroundStyle(Palette.green)
        Text(
          "현재 \(allTime.currentStreak) · 최장 \(allTime.bestStreak)\(a.rule(on:today)?.schedule == .weekly ? "주" : "회") 연속 성공"
        ).font(.subheadline)
      }
      Text("지속력은 전체 기록 기준, 활동량·실행률은 선택 기간 기준이에요.")
        .font(.caption).foregroundStyle(.secondary)
      let plotted = Day.range(start, end).suffix(366).compactMap { day -> ChartPoint? in
        guard let amount = Progress.daily(a, day, entries).amount else { return nil }
        return ChartPoint(day: day, value: a.metric == .time ? amount / 60 : amount)
      }
      if !plotted.isEmpty {
        Chart(plotted) { p in
          BarMark(x: .value("날짜", p.day), y: .value(a.metric.unit, p.value)).foregroundStyle(
            Palette.green
          ).accessibilityLabel("\(p.day), \(p.value.formatted())\(a.metric.unit)")
        }.frame(height: 150).chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
          .accessibilityLabel("\(a.name) 활동량 차트")
      }
      if !previous.isEmpty && !values.isEmpty {
        let delta = total - previous.reduce(0, +)
        Text("기간 변화").font(.subheadline.bold()).foregroundStyle(Palette.green)
        Text("이전 같은 기간보다 \(delta >= 0 ? "+" : "")\(a.metric.display(delta))\(a.metric.unit)").font(
          .caption)
      } else {
        Text("기간 변화 · 비교할 측정 기록이 부족해요.").font(.caption).foregroundStyle(.secondary)
      }
      if a.rules.contains(where: {
        $0.effective >= Day.add(start, -length) && $0.effective <= end && $0.id != a.rules.first?.id
      }) {
        Text("이 기간에 일정 또는 기준 변경이 있어요.").font(.caption).foregroundStyle(.secondary)
      }
      if a.running {
        let timed = entries.filter { $0.amount != nil && $0.amount! > 0 && $0.seconds != nil }
        if !timed.isEmpty {
          let km = timed.reduce(0) { $0 + $1.amount! }
          let seconds = timed.reduce(0) { $0 + $1.seconds! }
          Text(
            "전체 평균 페이스 \(Duration.seconds(seconds/km).formatted(.time(pattern:.minuteSecond)))/km"
          ).font(.subheadline)
        }
        let heart = entries.compactMap(\.heartRate)
        let cadence = entries.compactMap(\.cadence)
        if !heart.isEmpty {
          Text(
            "기록별 평균 심박수 \((heart.reduce(0,+)/Double(heart.count)).formatted(.number.precision(.fractionLength(0)))) bpm"
          ).font(.subheadline)
        }
        if !cadence.isEmpty {
          Text(
            "기록별 평균 케이던스 \((cadence.reduce(0,+)/Double(cadence.count)).formatted(.number.precision(.fractionLength(0)))) steps/min"
          ).font(.subheadline)
        }
      }
      ForEach(a.fields.filter { $0.kind == .number }) { f in
        if let value = Progress.customAggregate(f, entries: entries) {
          Text("\(f.name) \(f.aggregate == .sum ? "합계" : "평균"): \(value.formatted()) \(f.unit)")
            .font(.subheadline)
        }
      }
    }.card()
  }
}
private struct ChartPoint: Identifiable {
  var id: String { day }
  var day: String
  var value: Double
}
