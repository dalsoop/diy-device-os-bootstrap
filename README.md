# Device Install Media Catalog

[![CI](https://github.com/dalsoop/device-install-media-catalog/actions/workflows/ci.yml/badge.svg)](https://github.com/dalsoop/device-install-media-catalog/actions/workflows/ci.yml)

장비 설치 USB에 담을 운영체제·라이브 환경·부트로더의 공개 목록이다. 이
저장소는 이미지를 직접 보관하지 않는다. 공식 다운로드 주소, 버전, SHA-256,
메뉴 설명과 실행 방식을 작은 JSON 파일로 관리한다.

실제 다운로드와 USB 제작은
[Device Install Media Builder](https://github.com/dalsoop/device-install-media-builder)가
담당한다.

## 항목 찾기

```text
catalog/
├── index.json
├── bootloaders/
│   └── ventoy.json
└── entries/
    ├── debian-live.json
    ├── pop-os.json
    ├── proxmox-backup-server.json
    ├── proxmox-ve.json
    └── truenas-scale.json
```

`catalog/index.json`은 사용 가능한 파일을 등록한다. 각 OS는 독립 파일이므로
하나를 추가하거나 갱신해도 다른 항목과 충돌하지 않는다.

## 항목 추가

1. 이 저장소를 포크한다.
2. `catalog/entries/<id>.json`을 추가한다.
3. `catalog/index.json`에 ID와 경로를 등록한다.
4. 공식 출처에서 받은 SHA-256과 HTTPS 주소를 확인한다.
5. `bin/verify-catalog`를 실행하고 Pull Request를 보낸다.

개인 전용 이미지나 자동설치 프로필은 이 공개 카탈로그에 넣지 않는다. 그런
항목은 Builder 포크의 `usb-media/local-entries/`에서 관리한다.

## 계약

- ID는 소문자·숫자·하이픈만 사용한다.
- 다운로드는 HTTPS만 허용한다.
- SHA-256은 소문자 64자리여야 한다.
- USB 밖으로 탈출할 수 있는 상대 경로를 거부한다.
- 설치기의 디스크 삭제 정책은 `boot_behavior`로 명시한다.
- 카탈로그 변경은 기존 Builder와 호환되는 스키마 버전을 유지한다.

```sh
bin/verify-catalog
```

카탈로그 통과는 메타데이터 형식과 고정값을 검증한다. 모든 장비에서 실제 부팅
및 설치가 성공한다는 뜻은 아니며, Builder의 VM·실장비 검증을 별도로 거쳐야
한다.

