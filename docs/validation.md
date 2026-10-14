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
