# 검증 기록

## 초기 상태
- Starting develop: 19eff3e
- main: 19eff3e
- git fetch 성공. 원격 develop 없음. 로컬 develop 생성, upstream 부재로 pull 생략.
- project-workflow: 문서와 링크 확인 PASS. 앱 테스트 NOT RUN: 아직 앱 없음.

## offline-records
- 초기 check FAIL: 의존성 설치가 완료되기 전에 실행해 vitest를 찾지 못함. 설치 완료 후 재검증 예정.
- 초기 로컬 기능 테스트 6개 및 타입 검사·빌드 PASS.
- npm audit에서 static/Vitest 취약 버전 발견. 수정 버전 전환 중 기존 설치 트리 peer 충돌 FAIL. 생성된 의존성 트리를 재설치하여 해결 진행.
- 수정 의존성 설치 완료: audit 0 vulnerabilities. 재검증 6 tests PASS, typecheck/build PASS.
- offline-records develop 병합 후 회귀: 6 tests/typecheck/build PASS.

## meal-tracking
- 식단 스냅샷, 외식 미상/거름, 요일 테스트 포함 9 tests/typecheck/build PASS.
- meal-tracking develop 회귀: 9 tests/typecheck/build PASS.

## device-sync
- 10 tests/typecheck/build PASS. 실제 SQLite/Fastify로 인증, 코드 재사용 거부, 중복 작업, 충돌, 삭제 및 커서 검증.
- device-sync develop 회귀: 10 tests/typecheck/build PASS.

## history-insights
- 13 tests/typecheck/build PASS. JSON/ZIP 왕복, CSV escaping, 누락값 집계 검증.
- history-insights develop 회귀: 13 tests/typecheck/build PASS.

## local-ai-entry
- 재개 시 상태: feature/local-ai-entry 변경 보존. 16 tests/typecheck/build PASS.
- Ollama 및 Tailscale CLI/앱 설치를 찾지 못함. 실제 로컬 모델 30개 한국어 예제/성능 측정은 NOT RUN. 테스트 입력과 실행 스크립트 제공.
- AI 서버 테스트 추가 중 테스트 코드 구문 오류 FAIL. 구문 수정 후 재검증.
- AI 출력 검증·날짜 기준·작업 중복 방지 포함 17 tests/typecheck/build PASS. AI 서버는 모의 모델 응답으로 검증.
- local-ai-entry develop 회귀: 17 tests/typecheck/build PASS.

## nrc-capture
- 최초 OCR 빌드 FAIL: 시스템 Swift module cache 쓰기 권한. 프로젝트 runtime 캐시로 변경.
- 최초 파서 테스트 FAIL 2건: 숫자가 뒤따르는 시간 라벨 미인식. 라벨 인식 범위를 수정.
- 파서 수정 후 22 tests/typecheck/build PASS, Swift OCR 컴파일 PASS.
- 제한된 샌드박스 OCR 실행 FAIL: Vision 시스템 서비스 접근 불가. 승인된 네이티브 실행에서 합성 PNG 5개 필드 인식 PASS.
- OCR 첫 실행 측정: 14.77초, maximum resident set 86,589,440 bytes, peak footprint 100,221,816 bytes. 합성 이미지 결과이며 실제 NRC 캡처 정확도는 NOT RUN(사용자 캡처 미제공).
- 성능 측정 호스트 확인: Apple M4, RAM 17,179,869,184 bytes (16GB).
- nrc-capture develop 회귀: 22 tests/typecheck/build PASS.

## mac-operation
- SQLite+첨부 백업 통합 테스트 포함 23 tests/typecheck/build PASS.
- LaunchAgent 생성 및 plutil 문법 검사 PASS. 로그인 항목 실제 등록은 아직 수행하지 않음.
- 최초 서버 실행 FAIL: tsx CLI의 샌드박스 IPC 권한. node --import tsx로 실행 방식을 바꾸고 승인된 로컬 서버 실행 PASS.
- 초기 E2E FAIL: 내비게이션 아이콘이 접근 가능한 버튼 이름에 포함되어 테스트의 정확한 이름 선택과 불일치. 장식 아이콘을 aria-hidden 처리하고 재검증.
- E2E 2차: 식단 보존·두 브라우저 동기화 PASS. 오프라인 수정 테스트는 저장 완료 전 reload, 모바일 테스트는 저장 버튼 이름 중복 매칭으로 FAIL. 완료 UI 대기와 정확한 선택자를 보완.
- 코드 검토에서 outbox UUID 정렬의 연속 수정 순서 위험 발견. IndexedDB 증가 순번·마이그레이션 추가, 새 기기 기본 템플릿을 서버에서 재사용하도록 수정.
- 미확정 캡처 초안 첨부의 전체 백업 누락 수정 및 회귀 테스트 추가.
- E2E 3차: 4/4 PASS (오프라인 재실행/내보내기, 식단 보존, 모바일 추가항목/원문 보존, 두 기기 동기화).
- 첫 설치 직후 오프라인 실행도 보장하도록 빌드 시 전체 앱 자산 precache 추가. iOS 홈 화면 PNG 아이콘 추가.
- 과거 활성 일정 보존·페이스 반올림·거리 가중 페이스 테스트 포함 28 tests PASS.
- 식단 AI 확인 처리 보완 중 typecheck FAIL: MealPlan 타입 import 누락. import 추가 후 재검증.
- E2E 추가 검증: 첫 설치 오프라인·캡처 ZIP 복원 PASS. 테스트별 서버 데이터 경로 격리 변경 후 worker 설정 재평가로 경로가 달라져 동기화 테스트 FAIL; 상속된 테스트 경로 재사용으로 수정.
- 복원 대기열 테스트 FAIL: 이전 테스트가 삭제한 IndexedDB 인스턴스 재개방 누락. 테스트 격리 수정.
- 최종 feature 검증: 단위·통합 31 tests PASS, typecheck/production build PASS, Chromium E2E 5/5 PASS. 첫 설치 오프라인 실행·수정, 식단 스냅샷, 모바일 사용자 항목·원문 보존, 두 브라우저 동기화, 오프라인 캡처 ZIP 복원을 검증.
- 연속 수정 전송 순서·응답 유실 재전송·충돌 처리·복원 중 기존 대기열 보존 및 서버 스냅샷 복원 테스트 PASS.
- 러닝 시간 입력을 분:초로 바꾸고 iPhone에서 콜론 입력 가능한 키보드를 사용.
- 실제 iPhone, 물리적 잠자기 복귀, Tailscale 외부 연결, Ollama 실모델 30개 예제/성능, 실제 NRC 캡처 정확도는 NOT RUN. 각각 실기기 접근·서비스 설치/계정·원본 캡처가 필요. LaunchAgent는 생성/문법 검증만 완료했고 시스템 등록은 미실행.
- 작업 재개 시 fetch PASS. 로컬 develop에 upstream이 없어 pull은 생략. Starting develop HEAD: 55e2a9b3cc66b23dfe0fafaa0fd41f5eee8f44ee. main: 19eff3e30c831d7db7676dc25915feb84fa2bfda.
