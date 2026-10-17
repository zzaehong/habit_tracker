# 차곡 2.0

작은 실천을 기록하고, 쌓인 변화를 확인하는 **iPhone 전용 앱**입니다.

SwiftUI · iOS 18+ · SwiftData. 계정, 서버, iCloud 없이 기기에 저장합니다.

프로토타입 소스 릴리스: [v2.0.0-prototype.1](docs/releases/v2.0.0-prototype.1.md) · 앱 버전 2.0.0 (1)

## 시작하기

Xcode에서 [`ios/Chagok.xcodeproj`](ios/Chagok.xcodeproj)를 열고 `Chagok` scheme과 iPhone Simulator를 선택해 실행하세요. 실기기는 본인의 서명 Team과 Bundle Identifier를 설정해야 합니다.

- **오늘:** 예정 활동, 빠른 완료, 상세 기록, 시간형 활동 타이머.
- **기록:** 날짜·활동별 조회, 수정, 삭제, 기존 기록 상세 보기.
- **성장:** 실제 활동량, 실행률, 지속력, 체크포인트와 XP·레벨.
- **설정:** 활동·추가 항목, 로컬 알림, 백업·복원, 보상 표시, 시간대.

독서와 러닝은 선택 가능한 템플릿입니다. 독서는 **읽은 페이지 수**, 러닝은 거리로 체크포인트를 계산합니다. 페이지·거리·시간·횟수·완료 방식의 활동을 직접 만들고 숫자·텍스트·선택 항목을 추가할 수 있습니다.

빠른 완료는 최소 달성을 인정하되 측정값을 만들지 않습니다. 미실천 XP 벌점은 없으며 기록 정정·삭제 시 보상을 재계산합니다.

## 데이터 보호

기기 간 자동 동기화는 제공하지 않습니다. 설정에서 JSON 또는 이미지 포함 ZIP을 내보내 파일 앱에 보관하세요. 기존 웹 차곡의 JSON/ZIP도 가져올 수 있습니다. ID 충돌은 미리보기에서 내용을 비교하고 선택합니다.

기존 웹·서버 소스는 Git 이력(`52e3229`)에 보존되어 있습니다. 실제 `runtime/` DB·이미지·백업과 과거 테스트 evidence는 삭제하지 않았습니다. 기존 브라우저 IndexedDB 데이터를 이전하려면 기존 웹에서 내보낸 JSON/ZIP이 필요합니다. SQLite 파일 직접 가져오기는 지원하지 않습니다.

## 문서와 검증

- [iPhone 실행·백업·배포 준비](ios/README.md)
- [제품·화면 설계](docs/ios-design.md)
- [Git Flow](docs/git-flow.md)
- [검증 기록 및 실행하지 못한 항목](docs/validation.md)
- [과거 웹 운영 문서](docs/history/web-operations.md)

```sh
swift test --package-path ios/ChagokCore --scratch-path runtime/swift-build
CHAGOK_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17e' ios/scripts/check.sh
```

빌드 산출물과 테스트 결과는 `runtime/`에 보관합니다. 실제 iPhone·실제 NRC 캡처·실기기 알림·VoiceOver·서명/TestFlight 검증은 시뮬레이터 테스트와 별도로 수행해야 합니다. 사용자 요청 없이 배포하지 않습니다.
