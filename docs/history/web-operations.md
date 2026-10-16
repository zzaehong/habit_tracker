# 맥미니 운영

## 로그인 후 자동 실행

먼저 `npm run build`, `npm run ocr:build`를 완료합니다. 실행 중인 수동 서버는 종료한 뒤 설정합니다.

```sh
npm run launchagent
mkdir -p "$HOME/Library/LaunchAgents"
cp runtime/local.chagok.server.plist "$HOME/Library/LaunchAgents/local.chagok.server.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.chagok.server.plist"
```

생성 도구가 현재 Node 실행 파일과 프로젝트의 절대 경로를 기록합니다. Node 설치 위치나 프로젝트 경로가 바뀌면 다시 생성해야 합니다. 자동 실행은 사용자 로그인 후 시작하며, 잠자기 중에는 동작하지 않습니다. 잠자기를 막거나 강제로 깨우지 않습니다.

중지·해제:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.chagok.server.plist"
```

로그: `runtime/server.log`, `runtime/server-error.log`. 기록 본문·이미지·토큰은 로그에 출력하지 않습니다. 로그 파일은 필요 시 서버를 중지하고 보관·정리하세요.

## 연결 상태

- **기기에 저장됨:** 연결 전 로컬 저장.
- **동기화 대기:** 아직 서버에 반영되지 않은 변경.
- **동기화 완료:** 전송 완료. 다른 기기는 열어야 새 내용을 받습니다.
- **확인 필요:** 같은 기록의 동시 수정 또는 복원 충돌.

Tailscale 앱이 두 기기에서 켜져 있어야 외부에서도 연결됩니다. HTTPS 주소를 바꾸기 전에는 JSON/ZIP 백업을 내보내세요. 브라우저의 주소별 저장소는 자동 이전되지 않습니다.

서버 기기 코드: `npm run pair`. 코드는 10분·1회 제한입니다. 설정에서 연결된 기기의 접근 권한을 취소할 수 있습니다.

## 서버 백업

서버가 실행 중일 때 하루 한 번 백업합니다. 잠자기로 놓친 경우 복귀 후 최대 약 1분 안에 다시 확인합니다. 설정에서 수동 백업도 가능합니다.

`runtime/backups/` 구성:

- 시각별 `.sqlite`: Node SQLite 온라인 백업 API로 생성한 DB 스냅샷.
- 같은 이름의 `.json`: 스냅샷에 포함된 이미지 해시 목록.
- `blobs/`: 해시로 중복 제거한 이미지 원본.

완료된 백업 목록 최근 30개와 이에 필요한 이미지들을 유지합니다. **이 폴더 전체**를 별도 디스크로 복사해야 완전한 백업입니다. 같은 SSD의 백업은 디스크 고장을 막아주지 않습니다. 백업에는 기기 인증 정보가 포함되므로 개인 파일로 보관하세요.

앱의 JSON은 이미지 메타데이터만 포함합니다. 이미지까지 이식하려면 ZIP을 사용하세요. ZIP 복원은 200MB 입력·300MB 압축 해제 한도가 있습니다. 그보다 큰 전체 데이터는 서버 백업으로 복원하세요.

## 서버 전체 복원

서버를 중지하고 존재하지 않는 새 폴더를 대상으로 복원합니다. 기존 DB를 덮어쓰지 않습니다.

```sh
npm run restore:server -- runtime/backups/<백업이름>.json runtime-restored
DATA_DIR=runtime-restored npm run server
DATA_DIR=runtime-restored npm run pair
```

복원은 이미지 해시를 확인하고 기기 인증을 초기화합니다. 앱에서 연결을 해제한 뒤 새 코드로 다시 연결하면 처음부터 변경 목록을 받습니다. 기존 기기의 미동기화 데이터는 삭제하지 마세요. 충돌 화면에서 필요한 기록을 선택합니다. 복원된 경로에도 OCR 바이너리가 필요하면 `runtime/ocr`를 복사하세요.

새 데이터 경로로 계속 운영하려면 LaunchAgent에 `DATA_DIR` 환경 변수를 추가하거나 기본 runtime 경로를 백업한 뒤 관리자가 경로를 전환하세요. 활성 SQLite 파일을 실행 중에 이동하지 않습니다.

## 업데이트

1. 서버 백업을 확인합니다.
2. 수동 서버 또는 LaunchAgent를 중지합니다.
3. 새 소스에서 `npm ci`, `npm run check`, 필요 시 `npm run ocr:build`를 실행합니다.
4. 서버를 다시 시작합니다.
5. 기기에서 앱을 다시 열고 동기화 상태를 확인합니다.

Service Worker는 현재 열린 앱을 강제로 교체하지 않습니다. IndexedDB 마이그레이션은 기존 기록과 전송 대기열을 보존합니다. 브라우저 데이터 삭제를 업데이트 방법으로 사용하지 않습니다.

## 알려진 검증 경계

실제 아이폰 Safari/홈 화면 앱·물리적인 맥 잠자기·Tailscale 외부망 연결은 해당 기기와 계정에서 확인해야 합니다. Chromium의 모바일 화면·네트워크 차단 테스트는 실제 iOS 검증을 대체하지 않습니다. Ollama와 실제 NRC 캡처가 없으면 모델 정확도와 해당 화면 OCR 정확도도 미검증으로 남습니다.
