# 차곡 iPhone 앱

SwiftUI · iOS 18 이상 · SwiftData 로컬 저장. 인터넷, 계정, iCloud 또는 맥미니 서버가 필요하지 않습니다.

## 실행

1. Xcode에서 `ios/Chagok.xcodeproj`를 엽니다.
2. `Chagok` scheme과 iPhone Simulator를 선택하고 실행합니다.
3. 실기기는 Signing & Capabilities에서 본인 Team과 고유 Bundle Identifier를 지정합니다. 서명 정보는 저장소에 포함하지 않습니다.

기본 템플릿은 독서(5/15/30쪽)와 러닝(1/3/5km)입니다. 온보딩에서 직접 선택하거나 사용자 활동을 만드세요. 수치는 선택 입력이며 빠른 완료는 수치를 만들어내지 않습니다.

## 저장과 백업

SwiftData 컨테이너에 버전 2 스냅샷을 저장하고 이미지 파일은 Application Support/ChagokImages에 해시 이름으로 보관합니다. 저장이 실패하면 이전 상태를 유지하고 오류를 표시합니다. 기기 간 동기화는 없습니다.

설정 → JSON 또는 이미지 포함 ZIP 내보내기 → 파일에 저장. ZIP 한도는 압축 파일 및 전체 해제 크기 각각 300MB입니다. JSON에는 원본 이미지가 포함되지 않습니다. 동일 ID 복원은 중복 생성하지 않고 내용이 다르면 사용자 선택을 요구합니다.

기존 웹 백업 `format: chagok, version: 1`을 지원합니다. 모든 원본 엔티티를 보관하며 독서/러닝/공부/일반 활동은 새 방식으로 변환합니다. 식사·웨이트·과외 상세는 이전 기록 화면에서 확인합니다. 기존 기록은 기본 XP 지급 대상이 아니며 설정에서 기간별 실측 기록만 미리 보고 소급할 수 있습니다.

기존 웹의 runtime DB·원본 이미지는 저장소 정리 시 삭제하지 않습니다. 웹 코드의 마지막 버전은 Git `52e3229`에서 확인할 수 있습니다. 웹의 로컬 IndexedDB 기록은 웹에서 내보낸 JSON/ZIP이 필요하며 SQLite 파일을 직접 가져오지는 않습니다.

## 개발·검증

```sh
swift test --package-path ios/ChagokCore
xcodebuild -project ios/Chagok.xcodeproj -scheme Chagok -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/Chagok.xcodeproj -scheme Chagok -destination 'platform=iOS Simulator,name=iPhone 17e' CODE_SIGNING_ALLOWED=NO test
```

프로젝트에 Swift 파일을 추가하면 `python3 ios/scripts/project.py`로 프로젝트를 재생성합니다. 외부 패키지 의존성은 없습니다. ZIP은 zlib, 해시는 CryptoKit, OCR은 Vision을 사용합니다.

`--uitesting`은 메모리 저장소를 사용합니다. Debug의 `--test-store UUID`는 지정 UUID의 별도 영속 테스트 저장소를 사용합니다. 사용자 데이터 초기화 옵션은 없습니다.

## 알림·OCR

사용자가 알림을 설정할 때만 권한을 요청합니다. 앞으로 28일, 전체 최대 60개의 알림을 예약합니다. 주 N회는 월요일 안내입니다. 활동 편집에서 시각을 지정하고 설정에서 전체 알림을 켜거나 끌 수 있습니다. 저장 및 앱 실행·복귀 시 예약을 갱신합니다.

NRC PNG/JPEG 캡처는 최대 5장, 장당 10MB입니다. 기기에서 OCR 후 추출값과 원본을 확인하고 반영합니다. 숫자 충돌은 수동 확인하며 없던 값은 추정하지 않습니다. 저장하지 않은 이미지도 설정의 원본 관리에서 확인·삭제할 수 있습니다.

## 배포 준비

실기기 서명, Apple Developer 등록, 개인정보 처리방침·지원 URL, App Store Connect 메타데이터, 실제 iPhone 접근성·OCR 검증이 필요합니다. 사용자 요청 없이 업로드하거나 배포하지 않습니다. 데이터 수집 SDK·분석 서버·광고·결제는 포함하지 않습니다. 데이터는 기기와 사용자가 내보낸 백업에만 남습니다.

실제 NRC 캡처와 실제 iPhone 검증은 시뮬레이터 통과와 별도로 기록합니다. 이 앱의 게임 XP는 건강·능력 평가가 아닙니다.
