# 하네스 개발 플로우 (v4, 범용 · 병렬 · 지속 변경)

README.md나 CSV가 없어도, 웹이 아니어도(API, CLI, 라이브러리, 워커, 모바일), 서비스가 여러 개여도, 기존 코드가 있어도 같은 스킬로 진행함.
- 4~5단계는 hm-auto로 한 대화창에서 자동 실행할 수 있음. 서로 의존하지 않는 task는 동시에 돌림.
- 셋업 뒤에 요구사항이 추가되거나 바뀌면 hm-change로 반영함. 1~3단계를 다시 하지 않음.

프로젝트 성격과 작업 방식은 1단계에서 `.harness/config`에 기록하고, 이후 모든 스킬과 `scripts/hm.sh`가 이 파일을 따름.
필요한 도구는 git과 bash뿐임. make 같은 빌드 도구는 쓰지 않음.

v3에서 바뀐 점은 `CHANGELOG.md`에 있음.

## .harness/config

1단계(hm-req)가 저장소를 스캔해 추정하고, 내가 한 번에 확인함. MODE, SESSION_PER_TASK, 작업 방식(PARALLEL, WORKTREES, MERGE)은 추정하지 않고 나에게 직접 물어서 확정함. 셋은 하나로 묶지 않고 각각 따로 물음. 하네스를 몰라도 고를 수 있게, 선택지마다 실제로 어떻게 진행되는지(누가 어느 대화창을 여는지, 무엇이 동시에 돌아가는지, 어디서 병합하는지, 얻는 것과 잃는 것)를 풀어서 설명함. 예를 들어 SESSION_PER_TASK는 세션이 무엇인지, 새 세션과 같은 세션의 차이, 나중에 바꿀 수 있다는 점까지 안내함.

```
MODE=FULL
SESSION_PER_TASK=1
REQ_SOURCES=README.md
DATA_SOURCES=data/
PROTECTED=README.md data/
GREENFIELD=1
HAS_SERVER=1
HAS_UI=1
HAS_LOAD=0
INTEGRATION=main
MERGE=local
REMOTE=origin
PARALLEL=1
WORKTREES=0
WORKTREE_DIR=../myapp-wt
CHAT_LANG=Korean
DOC_LANG=English
AGENT_FILES=CLAUDE.md
```

| 키 | 의미 | 예 |
|---|---|---|
| MODE | FULL / HACKATHON. 기본값(질문 수, 리뷰 정책, 처음 task 수)만 정함 | 시간 제한이 하루 미만이면 HACKATHON |
| SESSION_PER_TASK | 1 = task마다 새 세션, 0 = 데모 확인 후 같은 세션에서 다음 task 가능 | 추천: FULL 1, HACKATHON 0 |
| REQ_SOURCES | 요구사항 원천 파일. 없으면 `INTERVIEW` | `docs/PRD.md`, `INTERVIEW` |
| DATA_SOURCES | 분석·적재할 데이터. 없으면 비움 | `data/`, `seed.sql` |
| PROTECTED | 수정 금지 경로. 비우면 검사 생략 | `README.md data/ legacy/` |
| GREENFIELD | 1 = 새 프로젝트, 0 = 기존 코드에 추가 | |
| HAS_SERVER | 계속 떠 있는 프로세스가 하나라도 있음 (HTTP 서버, UI 개발 서버, 워커, 컨슈머). 0 = CLI, 라이브러리, 일회성 배치 | |
| HAS_UI | 화면이 있음 (브라우저, 모바일, 데스크톱). HAS_SERVER와 무관 | |
| HAS_LOAD | 동시 사용자 부하 목표 여부 (HAS_SERVER=1 필요). 단일 호출 성능 목표는 이 키와 무관하게 SPEC §10b 벤치마크로 처리 | |
| INTEGRATION | task가 갈라져 나오고 다시 병합되는 브랜치 | `main`, `develop` |
| MERGE | local = 리뷰 끝난 task를 로컬에서 INTEGRATION에 병합. pr = task 브랜치를 REMOTE에 push하고 팀이 PR로 병합 | 혼자면 local, 팀이면 pr |
| REMOTE | MERGE=pr일 때 push할 원격 | `origin` |
| PARALLEL | 동시에 In Progress일 수 있는 task 수 (자동 실행에서는 동시 서브에이전트 수) | 1, 2, 3 |
| WORKTREES | 1 = task마다 별도 worktree(병렬이면 필수), 0 = 메인 작업 트리에서 task 브랜치를 바꿔 가며 작업 | |
| WORKTREE_DIR | worktree를 만들 폴더. 저장소 밖, 공백 없음 (테스트 러너가 다른 worktree를 스캔하지 않게) | `../myapp-wt` |
| PORT_STEP | (선택) worktree마다 포트를 얼마씩 밀지. 기본 10 | |
| CHAT_LANG | 나와 대화하는 언어. 내가 쓰는 언어로 정함 | `Korean`, `English` |
| DOC_LANG | REQUIRE, SPEC, task 파일, 리뷰, 커밋 요약의 언어. 기존 문서가 있으면 그 언어, 없으면 영어. 코드·식별자·스크립트가 읽는 값(Status, Type, Verdict 등)·ID 형식·템플릿 제목은 항상 영어 | `English`, `Korean` |
| AGENT_FILES | AGENTS.md를 가리키는 다른 에이전트의 규칙 파일. 저장소에 이미 있는 것 + 기본 CLAUDE.md. 비우면 만들지 않음 | `CLAUDE.md GEMINI.md` |

작업 방식 추천 프리셋:

| 상황 | PARALLEL | WORKTREES | MERGE |
|---|---|---|---|
| 혼자, 순차 (해커톤) | 1 | 0 | local |
| 혼자, 병렬 | 2~3 | 1 | local |
| 팀 | 원하는 만큼 | 1 | pr |

형식: 한 줄에 `KEY=value` 하나, `=` 앞뒤에 공백 없음. 값은 줄 끝까지 그대로 읽음 (따옴표 불필요). 값 뒤에 주석을 달면 안 되고, 목록(PROTECTED 등)의 경로에는 공백이 있으면 안 됨. 형식이 틀린 줄이 있으면 `hm.sh`가 줄 번호와 함께 실패함.
3단계(hm-setup)가 이 파일 아래에 명령 섹션을 덧붙임 (아래 "하네스 명령").
worktree마다 `.harness/local`(gitignore)에 `PORT_OFFSET=<n>`이 있어서, 동시에 떠 있는 worktree끼리 포트가 겹치지 않음. 메인 작업 트리는 0.
이미 config가 있으면 1단계는 다시 감지하지 않고, 바뀐 키만 물어서 갱신함. 요구사항 변경은 hm-change로 안내함.

## 설정에 따라 달라지는 것

| 설정 | 영향 |
|---|---|
| SESSION_PER_TASK=0 | "Start Task <id>."를 같은 세션에서 받을 수 있음. 데모 확인 게이트, 한 세션에 한 task, 리뷰는 별도 세션이라는 규칙은 그대로임. 다음 task 시작 시 문서를 다시 읽고, 기억보다 문서와 git log를 믿음. 컨텍스트가 길면 새 세션 권장 |
| REQ_SOURCES=INTERVIEW | 인터뷰가 "무엇을, 누구를 위해, 핵심 시나리오"부터 시작. 기본 질문 수 증가 (FULL 15, HACKATHON 8). REQUIRE 초안은 아는 것만으로 시작하고 인터뷰가 채움 |
| DATA_SOURCES 비어 있음 | REQUIRE §4, SPEC 적재 절차, Task 0 적재가 N/A |
| GREENFIELD=0 | hm-setup이 설계 단계에서 기존 시스템과 컴포넌트 간 통신을 분석(별도 문서 없이 SPEC에 반영), REQUIRE §5 호환성 제약, SPEC에 Existing/Changed/New 표시, 변경 전 characterization test 필수, 기존 Makefile·패키지 스크립트 등은 그대로 두고 config의 명령에서 호출, 기존 AGENTS.md는 덮어쓰지 않고 섹션 추가, 하네스 커밋은 하네스 파일만 명시적으로 add |
| HAS_SERVER=0 | COMPONENTS가 비어 있음. SPEC §4가 CLI/라이브러리 계약. E2E는 subprocess 실행. dev-bg/stop/health/load는 skip. 성능 NFR은 SPEC §10b 벤치마크(`hm.sh bench`). 데모는 명령과 기대 출력 |
| 컴포넌트 2개 이상 | SPEC §2 컴포넌트 표, §4c 컴포넌트 간 계약, task마다 경계를 넘는 E2E, 계약 양쪽 테스트. Task 0에서 전부 기동 |
| HAS_UI=0 | 화면, 디자인 토큰, UI E2E 도구, test-id 검사 생략. 서비스가 있으면 E2E는 블랙박스 클라이언트 테스트 |
| HAS_LOAD=0 | SPEC §10a N/A, load 타깃 skip. 성능 목표가 §10b에 있으면 성능 테스트 스킬은 벤치마크만 실행, 없으면 바로 종료 |
| SPEC §10b 비어 있음 | bench 타깃 skip, tests/bench/ 없음 |
| PARALLEL>1 | WORKTREES=1 필요. 같은 파일을 고칠 task끼리는 hm-setup/hm-change가 Depends on으로 묶어서 동시에 돌지 않게 함 |
| MERGE=pr | task 시작 커밋 직후 브랜치를 push함 (= 이 task를 내가 맡았다는 표시). 리뷰를 마친 브랜치는 push만 하고, 병합은 팀 PR로 함. 스크립트는 `<REMOTE>/<INTEGRATION>`을 기준으로 상태를 계산함 (실행 때 fetch). hook은 각자 PC에서만 돌므로, 셋업이 PR마다 `hm.sh setup → check → test → e2e`를 돌리는 CI 작업 하나를 저장소의 CI에 추가함 |

SPEC과 REQUIRE는 해당 없는 섹션도 번호를 유지하고 `N/A (<키>=<값>)` 한 줄로 표시해서 참조 번호가 흔들리지 않게 함.

## 폴더 구조

```
Root (메인 작업 트리, INTEGRATION 브랜치)
├─ .harness/config    (1단계 생성, 3단계 설치 스크립트가 명령 섹션 추가)
├─ .harness/guardrail-samples (3단계. 가드레일 패턴을 검증할 예시 줄, `hm.sh selftest`가 읽음)
├─ .harness/local     (gitignore, worktree별 PORT_OFFSET)
├─ AGENTS.md          (3단계 생성, 기존 파일이 있으면 섹션 추가)
├─ CLAUDE.md 등       (AGENT_FILES. "AGENTS.md를 먼저 읽어라" + `@AGENTS.md` 두 줄. 기존 파일이면 덧붙임)
├─ .githooks/         (pre-commit: hm.sh check --hook (스테이징된 코드 자동 포맷 후 검사, 그 파일만 lint, Markdown만 스테이징이면 lint 생략), commit-msg: 형식 검사)
├─ scripts/
│  ├─ hm.sh            (하네스 명령: setup, migrate, dev, dev-bg, stop, health, status, test, e2e, load, bench, security, fmt, check, selftest, help)
│  └─ harness-state.sh (상태 판단: 다음 단계, worktree 경로·포트, 결과 확인)
├─ docs/
│  ├─ BRIEF.md        (채팅으로 붙여넣은 요구사항이 있을 때 1단계가 저장)
│  ├─ REQUIRE.md      (§11 질문 목록에 바로 답을 적을 수 있음. 예전 버전의 DISCOVERY.md가 있으면 계속 읽음)
│  ├─ SPEC.md
│  ├─ DECISIONS.md
│  ├─ REVIEW.md
│  ├─ STANDARDS.md    (보안·백엔드 기본 규칙, 코드 냄새 기본 목록, 프로젝트 규칙. 리뷰 Standards 축의 기준)
│  ├─ tasks/          (task마다 <id>.md, 템플릿 _template.md)
│  ├─ changes/        (hm-change의 CR-<n>.md)
│  ├─ reviews/        (리뷰 반영 때 리뷰 결과를 복사해 커밋)
│  ├─ LOAD_TEST.md    (6단계, SPEC §10에 목표가 있을 때)
│  ├─ security/       (hm-security의 review-<k>.md. 덮어쓰지 않음)
│  └─ TRACEABILITY.md (6단계)
├─ <components>/      (SPEC에서 결정. 예: api/, web/, worker/)
├─ tests/ 등          (SPEC §2 TEST_DIRS. 컴포넌트 안에 같이 있어도 됨)
├─ artifacts/         (gitignore: e2e 스크린샷, 리뷰 원본, 자동 실행 로그, 탐색 노트(notes/), 디버그 임시 파일(debug/), load/bench 결과, 보안 스캔 보고서)
└─ .run/              (gitignore: pid, 로그, 자동 실행 상태)

../<repo>-wt/         (WORKTREES=1)
├─ 3/                 (task/3 브랜치의 worktree, PORT_OFFSET=10)
├─ 4/                 (task/4, PORT_OFFSET=20)
└─ review-3/          (리뷰용 임시 worktree, 끝나면 제거)
```

스킬 파일: `hm-*/SKILL.md` 9개 (수동 8개 + hm-auto). 일부 경우에만 필요한 내용은 따로 두고 그때만 읽음: hm-dev의 `references/tdd.md`(테스트 먼저 루프), `references/debug.md`(디버그 절차), `references/review-and-merge.md`(리뷰 반영·병합. 개발 세션은 읽지 않음), hm-setup의 `references/setup.md`(셋업, 설계가 끝난 뒤 읽음)와 `references/no-require.md`(REQUIRE 없이 시작할 때), hm-auto의 `references/stop-reasons.md`(멈췄을 때만 읽음), hm-req의 `references/interview.md`(§11 질문 양식과 인터뷰 절차. 초안의 §11을 쓸 때부터 읽음)와 `templates/REQUIRE.template.md`·`templates/config.template`(hm-setup도 읽음). 사용하는 에이전트의 스킬 경로에 폴더째 복사함.
- Codex: `~/.codex/skills/hm-*`
- Claude Code: `~/.claude/skills/` 또는 프로젝트의 `.claude/skills/`
- 복사본이라서 setup 폴더에서 스킬을 고치면 다시 복사해야 반영됨. 복사 명령은 아래 "자동 실행 > 설치"에 있음.

공통 규칙:
- 대화는 CHAT_LANG, 문서는 DOC_LANG, 코드는 영어. PROTECTED 경로는 수정 금지.
- **다른 스킬은 요청할 때만.** 각 스킬은 내 메시지가 이름으로 가리키거나 그 스킬의 단계가 명시한 스킬만 씀 (hm-auto가 돌리는 hm-dev·hm-review, 데모의 "수정 요청"에 따른 hm-change). hm-front-design이나 차트·문서 스킬처럼 설명이 맞아 보이는 스킬도 쓰지 않음. 예외는 내가 고른 것이 SPEC이나 DECISIONS에 기록된 경우뿐임 (예: hm-setup에서 "UI는 hm-front-design을 따른다"고 답하면 SPEC §9와 D-xx에 남고, 이후 개발 세션이 그 기록을 근거로 씀). 스킬끼리 절차도 빌리지 않음: hm-load-test·hm-security는 병합하지 않고 "Merge branch perf/<n>." / "Merge branch security/<n>."을 안내함. 다음 단계 안내와 스크립트·템플릿 파일 읽기는 됨. AGENTS.md에도 같은 규칙이 있어서 hm-auto의 서브에이전트도 따름.
- **내가 지정한 파일이 먼저.** 메시지에 파일을 적으면 그 역할의 첫 번째 근거로 씀 (예: "리뷰해: `docs/api-spec.md` 기준으로"). 하네스 문서는 빠진 내용만 채움. 둘이 다르면 차이를 보여 주고 어느 쪽을 따를지 물음. 파일이 없거나 역할에 안 맞으면 한 줄로 말하고 건너뜀. 읽기만 하고, 고쳐 달라고 할 때만 고침.
- 스킬의 트리거 문장("요구사항 정리 시작해" 등)은 예시임. 같은 뜻이면 어느 언어로 말해도 됨.
- 모든 질문은 같은 양식을 씀 (hm-req, hm-setup, hm-change는 스킬에, 나머지는 AGENTS.md "Ask the user when"에 있음). 질문에는 항상 추천안이 붙음. 추천할 수 없으면 무엇을 알아야 하는지 말하고, 그동안은 가장 안전한 선택을 추천함.

  ```
  ❓ **Q-08 — 누락된 환승 시간**: 동명 역 사이에 **공통 기본 환승 시간을 적용**해도 될까요? 된다면 몇 초인가요? `예솔`과 `금빛`은 이름이 같지만 데이터에 보행 시간이 없습니다.

  ➡️ 동명 역의 환승은 허용하고, 담당자가 확인한 공통 기본 시간을 적용하는 방식을 추천합니다.
  ```

  - 질문이 여럿이면 라운드로 물음. 다른 질문의 답을 기다리지 않아도 되는 질문을 한 메시지에 번호를 붙여 모두 묻고(hm-req·hm-change는 5개까지), 답에 따라 생기는 후속 질문은 다음 라운드로 넘김. "응"이라고만 해도 추천안이 채택되게 묻고, "1 추천대로, 2 B"처럼 번호로 답해도 됨.
  - 질문은 항상 메시지 맨 끝에 둠. 보고, 조사 결과, 표, 요약을 먼저 쓰고, 마지막 ➡️ 줄 뒤에는 아무것도 쓰지 않음. 예를 들어 hm-req는 프로필 표 → 질문, hm-setup은 "Defaults I chose" 표 → D-xx, hm-change는 영향 표와 task 목록 → 질문 순서임.
  - 질문을 먼저 씀. 콜론 바로 뒤에 물음표로 끝나는 문장이 오고, 이유·근거·개수·예시는 그 뒤에 붙임.
    - 좋은 예: "`updated_at`이 가장 최신인 행을 사용할까요? 예를 들어 `S201→S202`에는 2025년의 266초와 2026년의 176초가 함께 있습니다."
    - 나쁜 예: "서로 다른 기록이 있는 구간이 5쌍 있습니다. 예를 들어 … 최신 기록 하나만 사용하면 될까요?"
  - 굵은 글씨: ID와 주제, 결정의 핵심 구절.
  - 코드 표기: 이름, 값, 경로, ID. 터미널에서 강조 색으로 보임.
  - 선택지가 있으면 질문과 추천 사이에 `A) …`, `B) …` 한 줄씩 넣음. 선택지는 설정 키(`SESSION_PER_TASK=0` 등)가 아니라 실제로 어떻게 진행되는지, 무엇을 얻고 잃는지를 문장으로 설명함. 키는 끝에 괄호로 참고용으로만 붙임.
  - 색은 Markdown으로 직접 정할 수 없어서, 굵은 글씨와 코드 표기를 클라이언트가 강조 색으로 그려 주는 것에 맡김. HTML이나 색 코드는 쓰지 않음.
- AC ID는 항상 전체 형식 `R-01/AC-1`로 씀 (AC 번호는 R-xx마다 다시 시작함). 테스트 이름은 `test_r01_ac1_...` / `r01-ac1: ...` 또는 스택의 이름 규칙으로 같은 요소를 담음.
- ID(R-xx, D-xx, task, CR)는 한 번 쓰면 번호를 바꾸거나 재사용하지 않음. 추가는 항상 다음 번호.
- task ID는 기본이 숫자. 팀은 이슈 키나 `<이니셜>-<n>`도 됨 (`[A-Za-z0-9][A-Za-z0-9._-]*`).
- 필요한 도구: git(2.31 이상), bash(3.2 이상), (HTTP 컴포넌트) curl. Windows는 Git for Windows의 Git Bash.
- Windows에서는 PATH의 `bash`가 WSL 런처(`C:\Windows\System32\bash.exe`)일 수 있음. hm-setup이 `bash -c 'echo $OSTYPE'`로 확인하고, `msys`가 아니면 PATH에서 Git의 `bin` 폴더를 System32보다 앞에 두라고 안내함. git hook은 git 자체 셸로 돌아서 영향 없음.
- hook·스크립트는 ASCII만 씀 (Windows 콘솔이 한글을 깨뜨림). `.gitattributes`로 LF를 고정해서 CRLF 때문에 bash가 깨지지 않게 함.

## 하네스 명령 (`bash scripts/hm.sh <명령>`)

스킬, hook, 사람 모두 같은 명령 이름을 씀. `hm.sh`는 스킬 폴더에서 그대로 복사하고, 스택별 내용은 `.harness/config`의 명령 섹션에 한 줄씩 적음. 스크립트를 프로젝트마다 고치지 않음.
- 모든 명령이 항상 존재함. 설정으로 꺼진 명령은 `skip: <이유>`(예: `skip: HAS_LOAD=0`)를 출력하고 0으로 종료하므로, 스킬이 프로젝트 성격을 몰라도 됨.
- 기존 Makefile, 패키지 스크립트, task runner가 있으면 그대로 두고 config에서 호출함 (`TEST_CMD=make test`, `TEST_CMD=npm test`). `make test`처럼 쓰고 싶으면 `hm.sh`로 넘기기만 하는 얇은 Makefile을 둘 수 있음 (선택).

명령 섹션 예 (3단계가 SPEC §2에서 채움):

```
SERVICE=myapp
INSTALL_CMD=npm ci
TEST_CMD=npm test -- "$@"
E2E_CMD=npx <e2e 도구> test "$@"
LINT_CMD=npx <린터> "$@" && npx <포매터> --check "$@"
TYPECHECK_CMD=npx <타입 검사>
FORMAT_CMD=npx <포매터> --write --ignore-unknown "$@"
TEST_DIRS=api/tests web/src
COMPONENTS=api web
api_PORT=8000
api_DEV=cd api && npm run dev -- --port $api_PORT
api_HEALTH=http_has http://localhost:$api_PORT/healthz "$SERVICE-api"
web_PORT=5173
web_DEV=cd web && API_URL=http://localhost:$api_PORT npm run dev -- --port $web_PORT
web_HEALTH=http_has http://localhost:$web_PORT/ "$SERVICE-web"
```

- 명령은 `bash -c`로 실행되고, 그 전에 config의 모든 키가 환경 변수로 export됨. 그래서 명령 안에서 `$api_PORT`처럼 다른 키를 참조함.
- `HM_SLOT`은 worktree 번호임 (PORT_OFFSET / PORT_STEP. 메인 작업 트리 0, task worktree 1, 2, ...). 병렬 worktree가 같이 쓰면 안 되는 자원(DB나 스키마, 캐시 prefix, 큐 이름, docker compose 프로젝트 이름, 임시 폴더)은 이 값으로 이름을 만듦. 예: `DATABASE_URL=postgres://localhost:5432/myapp_$HM_SLOT`. 어떤 자원을 나눌지는 SPEC §2 "Per-worktree resources"에 적음.
- `INSTALL_CMD`는 worktree마다 한 번씩 돌므로(WORKTREES=1이면 task 시작마다 `hm.sh setup`), 다운로드 캐시를 worktree끼리 공유하는 형태로 씀. 전역 저장소가 있는 도구(pnpm, uv, cargo, go modules, Maven, Gradle)는 그대로 되고, npm은 `npm ci --prefer-offline`, pip는 worktree 밖 캐시 폴더를 씀.
- `TEST_CMD`, `E2E_CMD`에는 테스트 파일이나 이름 필터를 받는 자리에 `"$@"`를 넣음. 그러면 `hm.sh test <파일>`이 그 파일만 돌리고, 인자 없이 부르면 전체를 돌림. 개발 중 반복할 때는 고친 테스트만, task 끝·리뷰 반영 뒤·병합 뒤에는 전체를 돌림. `"$@"`가 없으면 `hm.sh help`가 알려 줌.
- `LINT_CMD`는 린터와 포매터의 검사 모드를 한 명령으로 묶은 것. `"$@"` 자리에 파일을 받아서, pre-commit(`check --hook`)은 **스테이징된 코드 파일만** 검사하고(Markdown만 스테이징된 커밋은 건너뜀), 직접 부르는 `check`는 프로젝트 전체를 검사함. 그래서 프로젝트가 커져도 커밋 시간이 같음.
- `TYPECHECK_CMD`는 프로젝트 전체 타입 검사임. 파일 단위로 자를 수 없어서 직접 부르는 `check`(task 끝, 리뷰, 병합)에서만 돌고 pre-commit에서는 돌지 않음. 타입 검사기가 없는 언어면 비움.
- `FORMAT_CMD`는 포매터임. 받은 파일(`"$@"`, 프로젝트 루트 기준 경로)을 그 자리에서 고치고, 다루지 않는 파일 종류는 건너뛰게 씀. **pre-commit이 스테이징된 코드 파일을 자동으로 포맷하고 다시 스테이징**하므로 포맷 때문에 커밋이 거부되지 않음. 제외: Markdown, PROTECTED, 하네스 파일(`scripts/hm.sh`, `scripts/harness-state.sh`, `.githooks/`, `.harness/`), 일부만 스테이징된 파일(다시 스테이징하면 스테이징하지 않은 변경까지 커밋되므로. 이 경우는 lint가 막고 `hm.sh fmt <파일>`로 고침). `"$@"`가 없으면 hook은 포맷하지 않음 (프로젝트 전체를 고쳐 버리므로).
- 린트·포매터는 둘 다 셋업 때 항상 고름. 스택에 그런 도구가 없을 때만 비우고, 마지막 보고에 그렇게 적음.
- `SECURITY_CMD`는 보안 스캔 명령임. 셋업 때는 패키지 관리자에 보통 내장된 의존성 취약점 검사만 넣음. 정적 보안 분석과 git 이력 비밀값 검사는 hm-security가 처음 돌 때 추가함. 정한 심각도(기본 High) 이상이 나오면 실패함. 느리고 네트워크가 필요할 수 있어서 `check`에는 넣지 않고, 의존성을 추가하거나 SEC-xx가 걸린 task와 hm-security만 실행함.
- `SECRET_PATTERN`은 커밋하면 안 되는 비밀값의 정규식임 (대소문자 무시). `check`가 staged·추적 파일 전체에서 찾으므로 pre-commit에서 막힘. 출력은 `파일:줄`만, 값은 출력하지 않음. 테스트용 가짜 값은 그 줄에 `harness:allow-secret`을 붙임. 기본값은 개인 키, 클라우드 접근 키 형식, password/secret/key/token 이름에 따옴표 값을 넣은 줄이고, 3단계가 프로젝트가 쓰는 서비스의 키 형식을 더함.
- `<c>_PORT`는 기본값임. `hm.sh`가 `기본값 + PORT_OFFSET`(load 때는 +100 더)으로 바꿔서 export하므로, worktree마다 포트가 함께 밀림.
- health check는 "포트가 열려 있다"가 아니라 "이 프로젝트의 그 컴포넌트다"를 확인함. `http_has <url> <문자열>`(hm.sh 내장)로 응답에 `<SERVICE>-<component>`가 있는지 봄 (`/healthz`의 `service`, UI 개발 서버의 meta 태그). 워커는 ready 표시나 ping 명령. 그래서 다른 프로젝트나 다른 worktree의 프로세스를 잘못 재사용하지 않음.
- 이미 쓰는 실행 도구가 있으면 `UP_CMD`/`DOWN_CMD`로 한 번에 띄우고 내릴 수도 있음. 준비 여부는 여전히 각 health check로 판단함.

| 명령 | HAS_SERVER=1 | HAS_SERVER=0 |
|---|---|---|
| setup | 의존성, E2E 도구 준비(E2E_SETUP_CMD), 마이그레이션(MIGRATE_CMD), hooksPath 설정 | 동일 |
| migrate | (DB가 있을 때) 이 worktree의 DB(`$HM_SLOT`으로 이름을 나눔)에 마이그레이션 적용 | 동일 |
| dev | 컴포넌트 전부 포그라운드 실행, 로그 표시. Ctrl-C로 전부 종료 | DEV_CMD (CLI 샘플 실행) |
| dev-bg / stop | 순서대로 기동, 각 health check 대기 / 프로세스 트리째 종료 (Windows 포함) | skip |
| health | 컴포넌트별 healthy / down | skip |
| status | `harness-state.sh status` | 동일 |
| test [인자] | 유닛 테스트 (인자 없으면 컴포넌트 전체, 있으면 그 파일·필터만) | 유닛 테스트 |
| e2e [인자] | 떠 있는 컴포넌트는 재사용하고 나머지만 띄움. 자기가 띄운 것만 종료. 인자는 test와 같음 | subprocess 블랙박스 테스트 |
| load | (HAS_LOAD) PORT_OFFSET+100 포트에 운영형 명령으로 전부 기동, 단계별 LOAD_CMD (`USERS`, `DURATION`, `OUT_DIR`, 목표 단계만 `TARGET_CHECK=1`) | skip |
| bench | (SPEC §10b) 단일 호출 벤치마크, 목표 미달이면 실패 | 동일 |
| security | SECURITY_CMD (셋업 때는 의존성 취약점만, hm-security 이후 정적 분석과 이력 비밀값 추가). 보고서는 artifacts/security/ | 동일 |
| fmt [파일] | FORMAT_CMD로 파일을 그 자리에서 포맷 (인자 없으면 프로젝트 전체) | 동일 |
| check | 가드레일 + LINT_CMD(전체) + TYPECHECK_CMD (`--hook`: 먼저 스테이징된 코드를 자동 포맷하고 다시 스테이징, 그 파일만 LINT_CMD, TYPECHECK_CMD 생략, Markdown만 스테이징이면 lint 생략) | 동일 |
| selftest | 가드레일 패턴을 `.harness/guardrail-samples`의 예시와 내장 예시로 검증하고, 잘못된 task 파일·PROTECTED 경로를 확인한 뒤 check 실행. 셋업 때 한 번 | 동일 |
| help | 명령 목록, 이 worktree의 포트와 HM_SLOT, skip되는 명령 | 동일 |

다른 프로세스가 포트를 차지하고 있으면 기동을 거부하고, 뒤 컴포넌트가 실패하면 앞에서 띄운 것을 정리함.

## 테스트 도구 선택

하네스는 특정 테스트 도구를 정해 두지 않음. 필요한 검사마다 LLM이 도구 하나를 추천하고 대안 하나를 함께 보여 줌.

| 언제 | 누가 | 무엇을 |
|---|---|---|
| 2단계 설계 | hm-setup | 단위, E2E(화면이 있으면 스크린샷 포함, 플랫폼에 맞게), 부하(HAS_LOAD=1), 벤치마크(§10b), 언어마다 린터·타입 검사·포매터, 의존성 취약점 검사 도구를 추천 (나머지 보안 스캔 도구는 hm-security가 추가). 보통 "Defaults I chose"에 넣고, 후보가 비슷하면 D-xx로 물어봄. SPEC §1(메이저 버전), §2(명령, TEST_DIRS), §7(사용법)에 기록. 웹 검색 없이 정하고, 로컬에서 확인 못 한 것은 `needs check`로 두어 Task 0이 확인 |
| 3단계 셋업 | hm-setup | (예전 SPEC) §1에 필요한 도구가 빠져 있으면 추천하고 물어본 뒤 추가 |
| 6단계 성능·보안 | hm-load-test, hm-security | 도구가 없거나 필요한 기능이 없으면 추천하고 물어봄 |

판단 기준 (순서대로): 저장소에서 이미 쓰는 것 또는 스택 언어 기본 → 하네스 명령에서 headless로 돌고 실패 시 0이 아닌 종료 코드 → 필요한 기능을 다 갖춤 → 새 의존성이 가장 적음 (HACKATHON은 이 기준을 가장 중시).
가드레일 패턴(SKIP_PATTERN, SELECTOR_PATTERN)과 검사 경로(TEST_DIRS, E2E_DIRS)도 고른 도구와 폴더 구조에 맞춰 3단계에서 작성함. 패턴은 `grep -E` 정규식을 그대로 씀 (따옴표, 쉼표, `#` 이스케이프 불필요).

## 가드레일 (`hm.sh check`)

전부 config와 SPEC §2의 값에서 읽어서 특정 파일에 묶이지 않음. 두 가지로 돎:
- pre-commit hook(`check --hook`): **이번 커밋에서 스테이징된 파일만** 검사함. 바뀌지 않은 파일(완료된 task 포함)은 커밋될 때 이미 통과했으므로 다시 보지 않음. 일부만 스테이징된 task 파일은 스테이징된 내용을 봄. 그래서 task가 늘어도 커밋 속도가 같음.
- 직접 부르는 `check`(task 끝, 리뷰, 병합 때, selftest): 저장소 전체를 검사함. 패턴을 바꾼 뒤 예전 파일까지 다시 보는 것도 이쪽 몫임. 파일 읽기는 bash 내장 기능만 써서 task 수가 많아도 빠름.

| 검사 | 조건 |
|---|---|
| PROTECTED 경로가 harness-init 이후 변경되지 않음 (커밋, staged, 수정, 새 파일 모두) | PROTECTED가 비어 있으면 생략 |
| 비밀값이 staged·추적 파일에 없음 (SECRET_PATTERN. `.harness/config`, `.harness/guardrail-samples`, `harness:allow-secret` 줄은 제외) | SECRET_PATTERN이 있을 때 |
| 디버그용 임시 코드(`HM-DEBUG` 태그)가 staged·추적 파일에 없음 (Markdown 제외) | 항상 |
| 스킵된 테스트 없음 (SKIP_PATTERN, TEST_DIRS 전체) | 항상. 목록에 있는 폴더가 없으면 경고 출력 |
| E2E가 선택자 정책을 지킴 (SELECTOR_PATTERN, E2E_DIRS). `test-id`면 test-id만, `test-id+role`이면 role(접근성 이름 포함)도 허용, `none`이면 패턴을 비워서 검사 안 함 | HAS_UI=1 |
| task 파일의 Status, Type, Review 값이 정해진 목록 안에 있음 | 항상 |
| LINT_CMD 통과 (포맷 검사 포함. pre-commit은 그 전에 스테이징된 코드를 FORMAT_CMD로 자동 포맷하고, 그 파일만 검사함) | LINT_CMD가 있을 때. pre-commit은 Markdown만 스테이징된 커밋이면 생략 |
| TYPECHECK_CMD 통과 | TYPECHECK_CMD가 있을 때. 직접 부르는 `check`만 (pre-commit에서는 돌지 않음) |
| 커밋 메시지 `<type>(scope): ...` (scope에 대문자·점 허용, Merge/Revert 통과) | commit-msg hook |

**패턴 검증 (`hm.sh selftest`).** 셋업 때 가드레일이 실제로 걸리는지 한 번에 확인함. 위반 파일을 만들거나 임시 저장소를 쓰지 않음.
- 에이전트가 `.harness/guardrail-samples`에 예시 줄을 적음: 테스트 도구의 스킵 방식마다 `skip:`, 금지·허용 선택자마다 `selector-deny:`·`selector-allow:`, 추가한 키 형식마다 가짜 값 `secret:`.
- `selftest`가 각 예시를 해당 패턴에 대 봄. 내장 예시(개인 키, 클라우드 키, 따옴표 비밀번호, 디버그 태그), 잘못된 task 파일, PROTECTED 경로 존재도 확인하고, 마지막에 현재 트리에서 check를 돌림.
- 패턴을 고친 뒤에도 다시 돌림.

## 모드

모드는 기본값만 정함. 상한이 아님.

| 항목 | FULL | HACKATHON |
|---|---|---|
| 질문 목록의 필수 질문 수 (기본. 넘는 것은 `optional`, 파고들기 모드는 제한 없음) | 10 (INTERVIEW면 15) | 5 (INTERVIEW면 8) |
| D-xx 결정 (기본) | 5 | 3 |
| 처음 계획 | Task 0 + 약 5개 vertical slice | Task 0 + 약 3개 |
| 리뷰 정책 기본값 | 되돌리기 어려운 변경(one-way door)만 `each`: 저장된 데이터를 지우거나 좁히거나 다시 쓰는 마이그레이션, 로그인·인증 정보·접근 제어(SEC-xx), 저장소 밖에서 의존하는 계약(공개 API, 공개 파일·이벤트 형식). 나머지는 `batch` + 마지막 "Review all" | FULL과 같음 |
| 부하 테스트 | 10 / target / 2x | target 1회 |

기본 개수에 도달했는데 중요한 질문이나 결정이 남으면, 계속할지 한 번 물어봄. task는 크기 기준(한 세션 분량, 대략 R-xx 3개 또는 AC 8개 이하)으로 나눔.

## 단계별 스킬

| 단계 | 스킬 | 내가 입력할 문장 | 세션 | 산출물 | 사람 게이트 |
|---|---|---|---|---|---|
| 1 | hm-req | "요구사항 정리 시작해" (+ "끝까지 파고들어") | A | config, REQUIRE (+ 용어집, 질문 목록) | 모드·작업 방식·프로필 확인, 인터뷰, 요약 확인 |
| 2~3 | hm-setup | "설계 시작해" / "하네스 만들어" (둘 다 같은 스킬) | A | DECISIONS, SPEC (컴포넌트, 컴포넌트 간 계약 포함), AGENTS, docs/tasks/, REVIEW, config 명령 섹션, hooks, scripts, git 커밋 | 기술 스택·D-xx 답 (멈추는 곳은 여기 하나), 마지막 보고에서 계획·task 확인 |
| 4 | hm-dev | "Start Task <id>." / "Continue Task <id>." (하네스 없이: "개발해: …") | task마다 (병렬이면 task마다 세션 하나씩) | task 브랜치·worktree, 코드, 테스트, 커밋 | 데모 확인 |
| 5-1 | hm-review | "Review Task <id>." / "Re-review Task <id>." / "Review all." / "Re-review all." / "Review range A..B." / "이 브랜치 리뷰해" | 별도 세션 | artifacts/review/*-<k>.md (덮어쓰지 않음) | — |
| 5-2 | hm-dev | "리뷰 반영해: <리뷰 파일>" (지적 0건이어도 실행. PR 코멘트 등 아무 형식도 됨) / "Merge Task <id>." / "Merge branch <브랜치>." | 개발 세션 (새 세션이어도 됨) | 수정 커밋, docs/reviews/, Done, 병합 또는 push | 재리뷰 여부, 충돌 판단 |
| 디버그 | hm-dev (`references/debug.md`) | "디버깅해: …" / "원인 찾아줘: …" / "왜 느린지 찾아줘" (bug task에서 원인이 안 보이거나 같은 테스트가 3번 실패하면 개발 중에 자동으로 씀) | task 세션 안 (task 없이 부르면 진단만) | task 파일 Diagnosis, 회귀 테스트, 수정 커밋 | 재현 루프를 못 만들면 질문 |
| 변경 | hm-change | "요구사항 추가해: …" / "요구사항 변경해: …" / "버그 등록해: …" / "수정 요청: …" / "Task N 나눠줘" | 아무 때나 | docs/changes/CR-<n>.md, REQUIRE·SPEC·DECISIONS 갱신, 새 task 파일 | 불명확하거나 큰 요청이면 질문, 영향 분석 확인 |
| 6-1 | hm-load-test | "부하 테스트 해" / "성능 테스트 해" | 새 세션 | perf 브랜치, LOAD_TEST.md (부하 + 벤치마크) | 계약·모델 변경 승인, 끝나면 "Merge branch perf/<n>." |
| 6-2 | hm-audit | "누락 검토해" | 새 세션 (중간에도 가능) | TRACEABILITY.md (추적표, 누락, 구조 개선 후보, 회고) | 수정 전 보고 |
| 6-3 | hm-security | "보안 점검해" / "보안 점검해: Task <id>" | 별도 세션 (중간에도 가능) | security 브랜치, 통과하는 보안 테스트, docs/security/review-<k>.md | 결과 확인 후 "Merge branch security/<n>.", "보안 리뷰 반영해: <파일>" |
| 4~5 자동 | hm-auto | "자동으로 진행해" / "Task 1~3 자동으로" / "Task 4,7 자동으로" / "데모 확인 없이 자동으로" | 대화창 하나 (단계마다 새 서브에이전트, 최대 PARALLEL개 동시) | 4~5단계 산출물 전부, artifacts/runs/ | 데모 확인, 질문 |

## 하네스 없이 쓰기

셋업하지 않은 저장소에서도 일부 스킬을 바로 쓸 수 있음. 각 스킬은 필요한 입력을 이 순서로 찾고, 결과물에 무엇을 썼는지 적음 (예: `Spec source: README.md (stand-in for REQUIRE.md)`):

1. 내가 메시지에 지정한 파일
2. 하네스 파일 (docs/REVIEW.md, REQUIRE.md 등)
3. 같은 역할을 하는 저장소의 파일 (CONTRIBUTING.md, PR 설명, 이슈, 설계 문서 등). 후보가 여럿이면 한 번 물음
4. 대체값 (스킬 세트의 템플릿을 직접 읽음, 기본값 사용, 해당 부분 생략)

하네스가 없으면(`.harness/config` 없음) `.harness/config`, AGENTS.md, `scripts/`, hook을 만들지 않음. 만들면 다른 스킬이 셋업이 끝난 것으로 착각하기 때문임. 그 세션에서만 기본값을 씀: 대화는 내 언어, 문서는 저장소 문서의 언어(없으면 영어), INTEGRATION은 기본 브랜치(`origin/HEAD`, 없으면 main·master), worktree 없음, 로컬 병합, `hm.sh` 대신 저장소의 명령(package scripts, Makefile 등. 모르면 한 번 물음). artifacts/를 git이 무시하지 않으면 리뷰·디버그 임시 파일은 OS 임시 폴더에 둠.

| 스킬 | 하네스 없이 | 줄어드는 것 |
|---|---|---|
| hm-review | "이 브랜치 리뷰해": 기본 브랜치와의 차이를 두 축으로 리뷰. 리뷰 가이드·기본 규칙은 hm-setup 템플릿을 직접 읽음 | 스펙(PR 설명, 이슈, 설계 문서)이 없으면 Spec 축 생략. 데모 시나리오가 없으면 데모 확인 생략 |
| hm-dev 리뷰 반영 | PR 코멘트, 다른 도구 결과 등 아무 형식의 리뷰를 RV 표로 정리해 저장한 뒤 그 브랜치에서 고치고 `fix:`로 커밋 | task 파일·Done·docs/reviews/ 갱신 없음. 병합은 "Merge branch <브랜치>."라고 할 때만 |
| hm-dev 디버그 | 현재 브랜치에서 재현 루프로 진단하고, 원하면 그 자리에서 회귀 테스트부터 써서 고침 | 진단 기록은 task 파일 대신 보고에 넣음. `HM-DEBUG`는 hook 대신 커밋 전에 직접 검색 |
| hm-dev 병합 | "Merge branch <브랜치>."로 기본 브랜치에 병합 | 개발 중 결정(DQ)을 REQUIRE로 옮기는 단계 없음 |
| hm-security | 공격 표면을 코드에서 뽑고, 체크리스트를 기준으로 테스트·리뷰 | SEC-xx 대신 체크리스트, 스캔 명령은 config 대신 리뷰 파일에 적음 |
| hm-dev 개발 | "개발해: <요청 또는 이슈 파일>": task 파일(`docs/tasks/<id>.md`)을 하네스 템플릿으로 만들고, 열린 값이 있으면 한 라운드 물은 뒤 `task/<id>` 브랜치에서 테스트 하나씩 실패 → 구현. 이미 있는 task 파일이면 "Start Task <id>."도 됨 | worktree·병렬·리뷰 정책 없음. AC는 task 자체 ID `T<id>/AC-n`, 개발 중 결정(DQ)은 task 파일에 남음. 끝나면 "이 브랜치 리뷰해" 또는 "Merge branch task/<id>." |
| hm-change | "요구사항 추가해: …", "버그 등록해: …": CR 파일과 task 파일만 씀 | 요구사항·설계 문서(대체 파일 포함)는 읽기만 하고 고치지 않음. 고쳐야 할 내용은 CR의 영향 표에 적음. 현재 브랜치에 커밋 |
| hm-audit | "누락 검토해: <요구사항 문서>": 문서의 문장에 `S-1`, `S-2` 번호를 붙여 구현·테스트와 짝지음 | task 열·설계 검사(호환성, 컴포넌트 계약)·PROTECTED 검사 없음. 구조 개선 후보와 회고는 최근 커밋 100개 기준. TRACEABILITY.md는 커밋하지 않고 위치만 알려 줌 |

| hm-setup | "하네스 만들어" (또는 "하네스 만들어: <요구사항 파일>"): REQUIRE.md가 없으면 지정 파일 → 저장소의 요구사항 문서(PRD, 스펙, README 기능 목록, 이슈) → 대화 순서로 근거를 찾아 짧은 REQUIRE 초안을 씀. 프로필은 저장소에서 감지하고, 모드·세션 방식·작업 방식과 열린 질문(최대 5개)을 한 라운드에 물은 뒤 config를 쓰고 설계(Part A)로 이어감 | hm-req 인터뷰를 거치지 않아 [ASSUMPTION]이 많음 (§1에 그렇게 적음). 나중에 확인·변경은 hm-change로. 멈추는 곳은 이 한 라운드와 D-xx 질문 두 번 |
| hm-load-test | "부하 테스트 해": 목표 숫자를 문서에서 찾거나 물어서, 저장소의 운영형 실행 명령으로 띄우고 단계별(10명, 목표, 2배)로 측정 | 포트 분리 없음. 도구와 실행 명령은 config 대신 LOAD_TEST.md에 적어서 다음 실행이 같은 방법을 씀 |

hm-auto만 하네스 전용임 (상태 판단 스크립트 없이 자동 실행을 믿을 수 없어서). hm-req는 원래 혼자 동작함.

**나중에 정식으로 셋업할 때.** 하네스 없이 만든 task 파일과 CR은 그대로 이어받음. hm-setup은 `harness-init` 태그나 AGENTS.md의 하네스 섹션이 있을 때만 갱신(Refresh)으로 보고, task 파일만 있으면 새로 셋업하면서 이어받음: ID·상태·브랜치·Log를 유지하고, 템플릿에서 빠진 칸(Review, Core, Requirements)을 채우고, `T3/AC-1 = R-02/AC-4`처럼 REQUIRE의 AC와 짝지음 (테스트 이름은 그대로). REQUIRE에 없는 기준은 물어봄. hm-req도 이 파일들을 맥락으로 읽어서 이미 만든 것이 요구사항에 빠지지 않게 함.

## Task 파일과 상태 흐름

task마다 `docs/tasks/<id>.md` 하나. 스크립트가 읽는 줄:

```markdown
# Task 3: Search
- Status: Todo
- Type: feature
- Review: each
- Core: yes
- Depends on: 1, 2
- Requirements: R-03, R-04
- Source: initial plan
```

그 아래에 Scope, Acceptance criteria, Demo scenario, Findings, Tests, Issues found, Log, Notes for Next Session이 이어짐. 진행 중 사용자 답변과 결정은 Log에 남겨서 다음 세션과 리뷰어가 볼 수 있게 함.

task 종류 (`- Type:`, 없으면 feature):

| 종류 | 언제 | 진행 방식 | 완료 기준 | 데모 |
|---|---|---|---|---|
| feature | R-xx의 새 동작이나 바뀐 동작 | 테스트 하나를 실패시키고 → 통과할 만큼만 구현 → 다음 테스트 (tracer bullet, `hm-dev/references/tdd.md`) | AC마다 통과하는 테스트 | 있음 |
| bug | 동작이 틀림 | 버그를 재현하는 실패 테스트 먼저 → 수정 (테스트는 회귀 테스트로 남음). 원인이 바로 안 보이면 디버그 절차 (hm-dev) | 수정 전 실패, 수정 후 통과 | 있음 (원래 재현 절차) |
| chore | 리팩터링, 의존성 업그레이드, 도구, 인프라 (의도한 동작 변화 없음) | 시작 전 test·e2e 통과 확인 → 변경 | 기존 테스트가 assertion 수정 없이 통과 | 없음 (근거 보고) |
| spike | 결정 전에 답해야 할 질문 (가능성, 라이브러리 선택, 느린 원인) | 조사, 필요하면 지정된 경로에만 프로토타입 | task 파일 Findings에 답, 근거, 추천, 후속 task 제안 | 없음 (추천 보고) |
| docs | 문서만 | 문서 수정 | 문서가 코드와 맞음 | 없음 |

chore·spike·docs는 R-xx 없이 `Requirements: none`이어도 되고, AC 대신 "Done when" 항목을 씀. 작업하다 종류가 다르다는 게 드러나면(동작을 바꿔야 하는 chore 등) 멈추고 물어봄.

```
Todo → In Progress → In Review ─(each: 리뷰, Blocker 없음)→ Done → 병합
                         ↑            │
                         └─(Blocker, 수정 후 Re-review)┘
                       In Review ─(batch: 데모 후 바로 병합)→ (INTEGRATION에서 In Review) ─(Review all)→ Done
Todo ─(hm-change: 더 필요 없음)→ Dropped
```

- 상태는 task 브랜치의 task 파일에 있음. INTEGRATION은 병합으로만 상태를 알게 됨. `harness-state.sh status`가 브랜치를 가로질러 보여 줌 (`hm.sh status`).
- 개발 세션은 In Review까지만 바꿈. Done 설정과 병합은 리뷰 반영 단계(hm-dev "리뷰 반영해" / "Merge Task")만 함.
- 다음 task는 Depends on의 task가 모두 INTEGRATION에 병합되었고(그곳 상태가 In Review나 Done), In Progress인 task가 PARALLEL개 미만이면 시작할 수 있음.
- 브랜치가 REMOTE에만 있는 task(MERGE=pr)는 다른 사람이 맡은 것으로 보고 건너뜀.
- 컨텍스트가 길어지면 `wip(task-<id>)` 커밋 + Notes for Next Session 갱신 후 새 세션에서 "Continue Task <id>."로 이어감 (SESSION_PER_TASK 값과 무관).
- 세션 방식과 작업 방식은 중간에 바꿀 수 있음: `.harness/config`를 고치면 다음 단계부터 적용됨 (PARALLEL을 2 이상으로 올리려면 WORKTREES=1도 함께).

### 개발 중 질문 (요구사항에 없던 엣지케이스, 알고리즘 선택)

개발하다가 AC와 도메인 규칙이 정하지 않은 결정이 나오면, 에이전트가 정해서 테스트에 굳히지 않고 물어봄.

| 묻는 것 | 묻지 않는 것 |
|---|---|
| 사용자나 다른 컴포넌트가 결과를 알아챌 엣지케이스: 빈 값·누락·중복, 같은 요청 두 번, 동점, 한도, 정렬, 반올림·단위, 시간대·날짜, 동시 변경, 일부 실패 | 결과에 차이가 없는 내부 선택 (자료구조, 함수 모양). 에이전트가 정하고 task 파일에 `Internal:`로 이유를 남김 |
| 결과가 달라지거나 되돌리기 어려운 알고리즘·방식: 정확 계산과 근사, 어느 기록을 쓸지, 동점 처리, 매칭 규칙, 저장 형식, ID 체계, 속도와 정확도의 교환 | |

1. 답과 상관없는 부분을 먼저 끝냄. 답을 짐작해서 코드에 넣지 않음.
2. ❓/➡️ 양식으로, 서로 답을 기다리지 않는 질문은 한 번에 번호를 붙여 물음 (hm-auto에서는 질문이 그대로 나에게 전달됨).
3. 답은 task 파일의 "Decisions during development"에 `DQ-n`으로 기록함 (behavior 또는 approach, 관련 R-xx, 질문 → 답 → 정해진 동작과 구체적인 값). 그 동작을 고정하는 테스트를 `task3-dq2` 같은 이름으로 씀.
4. 개발 중에는 REQUIRE를 고치지 않음. 병합할 때 hm-dev(리뷰 반영 단계)가 옮김.
   - behavior DQ는 해당 R-xx의 새 AC가 됨: `R-03/AC-5: … (clarified in Task 3 DQ-2)`.
   - approach DQ는 DECISIONS의 D-xx가 됨 (필요하면 SPEC도 고침).
   - 다음 task와 감사가 같은 기준을 쓰게 하려는 것임.
5. 리뷰 체크리스트 7번(Spec 축)은 묻지 않고 정한 관찰 가능한 동작을 Major로 지적함. hm-audit은 REQUIRE나 DECISIONS로 옮겨지지 않은 DQ를 누락으로 봄.
6. 기존 AC, 규칙, 계약을 바꾸는 답이면 요구사항 변경이라서 hm-change로 감.

### 어려운 버그 (hm-dev의 디버그 절차)

원인이 바로 보이지 않는 버그나 성능 저하는 추측 대신 정해진 순서로 찾음. bug task에서 원인이 안 보일 때, 또는 같은 테스트가 3번 실패하면 개발 중에 이 절차로 넘어감. 절차는 `hm-dev/references/debug.md`에 있어서 필요할 때만 읽음.

1. 재현 루프: 이 증상에서 정확히 실패하고, 매번 같고, 몇 초 안에 끝나는 명령 하나를 먼저 만듦. 만들기 전에는 원인을 추측하지 않음. 못 만들면 재현 절차·로그·입력 데이터를 요청함.
2. 축소: 입력과 단계를 하나씩 빼서 최소 재현을 만듦. 이것이 회귀 테스트가 됨.
3. 가설: 검증 가능한 가설 3~5개를 순위대로 task 파일 `## Diagnosis`에 적음. 사람을 기다리지 않음.
4. 계측: 한 번에 변수 하나. 임시 로그에는 `HM-DEBUG` 태그를 붙이고, `hm.sh check`가 남은 태그의 커밋을 막음. 성능은 측정부터 함. 가설이 두 바퀴 모두 틀리면 물어봄.
5. 수정: 실제 버그가 일어나는 지점에서 실패하는 회귀 테스트 → 수정 → 통과 → 원래 시나리오 재확인.
6. 정리: 맞았던 가설과 원인을 커밋 메시지와 task Log에 남김. 임시 파일은 `artifacts/debug/`에만 둠.

task 없이 부르면 진단만 하고 커밋하지 않음. 원인과 최소 재현을 보고하고 "버그 등록해: …"(hm-change)로 task를 만들도록 추천함.

## 브랜치와 리뷰 범위

태그 대신 브랜치와 리뷰 파일의 `Commit:` 줄로 범위를 정함. 그래서 병렬 브랜치나 다른 사람의 커밋이 섞이지 않음.
아래 INT는 INTEGRATION을 뜻함 (MERGE=pr이면 `<REMOTE>/<INTEGRATION>`).

| 브랜치 / 태그 | 만드는 곳 | 용도 |
|---|---|---|
| `task/<id>` | 4단계 시작 | task 작업. 리뷰 범위 `git diff INT...task/<id>` (task 자신의 변경만) |
| 리뷰 파일의 `Commit:` | 5-1단계 | 리뷰한 정확한 커밋. 재리뷰 범위 `git log -p --first-parent --no-merges <Commit>..task/<id>` |
| `fix/review-all-<k>` | 5-2단계 (전체 리뷰 반영) | 리뷰한 커밋에서 갈라짐. Blocker면 병합 전에 재리뷰 (`git diff <Commit>..fix/review-all-<k>`) |
| `change/CR-<n>` | hm-change (MERGE=pr) | 요구사항 변경 PR |
| `perf/<n>` | 6단계 | 성능 작업. 원하면 "Review range"로 리뷰한 뒤 "Merge branch perf/<n>."(hm-dev)로 통합 |
| `security/<n>` | 6단계 | 보안 테스트와 보안 리뷰. 테스트·문서뿐이라 별도 리뷰 없이 "Merge branch security/<n>."(hm-dev)로 통합 |
| `harness-init` 태그 | 3단계 | PROTECTED 검사 기준, 첫 "Review all" 시작점 |

리뷰는 리뷰 대상 커밋 위에서 돌림: task의 worktree가 깨끗하고 브랜치 끝에 있으면 거기서, 아니면 임시 detached worktree(`review-<id>`, 끝나면 제거)를 만들어서. 다른 task가 작업 중인 트리에서 테스트하지 않음.

데모 직접 확인 (HAS_UI=1, feature·bug task): 리뷰어에게 사용자처럼 화면을 조작할 도구(웹이면 조작 가능한 브라우저)가 있으면, task의 데모 시나리오를 직접 따라 하고 주변 입력(빈 값, 긴 값, 잘못된 형식, 같은 동작 두 번, 흐름 중간의 뒤로·새로고침, 좁은 화면)과 빈·로딩·오류 상태를 확인함. dev가 띄워 둔 데모가 healthy면 그대로 쓰고 끄지 않으며, 아니면 `dev-bg`로 띄우고 끝날 때 `stop`함. 데이터는 고유한 이름으로 직접 만들고 남의 데이터는 건드리지 않음. 차이는 재현 절차와 함께 지적으로 남기고(AC 미충족·크래시는 Blocker), 근거 스크린샷은 리뷰 파일 옆 같은 이름의 폴더에 둠. 도구가 없으면 `skipped: no UI tool`로 적고 건너뜀 (리뷰를 위해 도구를 설치하지 않음). Review all은 범위에 병합된 feature·bug task의 시나리오, Re-review는 수정이 닿은 단계만 확인함. 리뷰 파일에 `## Demo walkthrough` 섹션이 추가됨 (스크립트는 읽지 않음).

**리뷰의 두 축.** 한쪽이 다른 쪽을 가리지 않게 따로 보고 따로 보고함. 요청대로 만들었지만 프로젝트 방식을 어긴 코드, 방식은 다 지켰지만 엉뚱한 것을 만든 코드를 둘 다 잡기 위함임.

| 축 | 질문 | 기준 | 체크리스트 |
|---|---|---|---|
| Spec | 요청한 것을 만들었나 | task 파일(개발 중 결정 포함), REQUIRE의 R-xx, SPEC | 1~9: 목표, 계약, 데이터 모델, 도메인 규칙, 데이터 처리, 호환성, 묻지 않고 정한 동작, 요청 밖 동작, 데모 확인 |
| Standards | 이 프로젝트 방식대로 만들었나 | docs/STANDARDS.md(프로젝트 규칙 → 기본 규칙 → 코드 냄새), AGENTS.md 금지 사항 | 10~15: 테스트 품질, 오류 처리, 보안, 데이터·자원, 금지 사항, 프로젝트 규칙과 코드 냄새 |

- diff가 크고(변경 약 300줄 초과) 서브에이전트를 쓸 수 있으면 두 축을 새 맥락의 읽기 전용 서브에이전트 두 개로 동시에 돌림. 작은 diff나 서브에이전트가 없을 때는 리뷰어가 Spec 축을 먼저 끝내고 Standards 축을 봄 (작은 diff에서는 서브에이전트를 띄우는 비용이 더 큼). 테스트 실행과 데모 확인은 리뷰어가 직접 함 (이 worktree의 포트가 필요해서).
- 리뷰 파일의 Findings는 `### Spec`, `### Standards` 표 두 개로 나뉘고, RV 번호는 두 표에 걸쳐 이어짐. 축을 섞거나 순위를 다시 매기지 않음. `Axes:` 줄에 축별 개수와 가장 심한 등급을 적음.
- 코드 냄새(Fowler의 12가지)는 판단 사항이라 최대 Minor임. 프로젝트 규칙이 허용하는 패턴이면 지적하지 않음.
- STANDARDS.md가 없는 예전 프로젝트는 AGENTS.md의 "Security", "Backend baseline"과 hm-setup 스킬의 STANDARDS 템플릿을 기준으로 씀.

**반복되는 지적은 검사로.** 리뷰를 반영할 때 지적마다 종류를 나눔. 기계적인 것(정해진 패턴: 금지된 호출, import 모양, 파일 위치, 빠진 속성)은 보고 끝에 "Checks to add"로 어떤 검사(LINT_CMD 규칙이나 가드레일 패턴)를 넣으면 될지 제안하고, 내가 승인하면 hm-change로 chore task가 됨. 판단이 필요한 것은 같은 종류가 예전 리뷰에도 있었으면 STANDARDS.md "Project rules"에 한 줄 추가함.

### 통합 (hm-dev "Integrate")

1. INTEGRATION을 task 브랜치로 먼저 병합함 (MERGE=pr이면 fetch 후 `<REMOTE>/<INTEGRATION>`).
   - 문서, lockfile(설치 명령으로 재생성), 기계적인 충돌만 직접 해결함.
   - 로직 충돌은 병합을 취소하고 나에게 물어봄. 리뷰된 코드가 바뀌기 때문임.
2. 병합으로 Markdown이 아닌 파일이 바뀌었을 때만 `hm.sh test`, `e2e`, `check`를 다시 돌림. 문서만 바뀌었거나 바뀐 게 없으면 병합 전 마지막 전체 실행(개발 끝, 리뷰, 리뷰 반영) 결과가 그대로 유효하므로 건너뜀. 리뷰 반영도 수정이 문서뿐이면 `check`만 돌림.
3. 마무리는 설정에 따라 다름.
   - MERGE=local: 메인 작업 트리(INTEGRATION)에서 `git merge --no-ff`, worktree를 정리함.
   - MERGE=pr: 브랜치를 push하고 PR 본문을 `artifacts/pr/<브랜치>.md`에 씀: 요약(사용자·호출자에게 무엇이 바뀌는지 가장 작은 목록이나 표), 증거(테스트 수, 리뷰 파일, 데모 스크린샷), 병합 위험(되돌릴 수 있는 변경인지, 틀리면 누가 무엇이 깨지는지), 닫는 task와 R-xx. 그 본문으로 PR을 열라고 안내함. 병합되면 끝남.

## 요구사항 인터뷰 (hm-req)

목표는 양식 채우기가 아니라 같은 이해에 도달하는 것임. 제품, 규칙, 용어를 나와 에이전트가 똑같이 설명할 수 있을 때까지 물음.

- **먼저 읽고, 못 찾은 것만 물음.** 요구사항 문서, 데이터(직접 쿼리), 기존 코드로 답할 수 있는 건 묻지 않고 찾은 내용을 근거와 함께 알려 줌.
- **문서는 REQUIRE.md 하나.** 별도 분석 문서(예전 DISCOVERY.md)를 쓰지 않고, 읽은 직후 REQUIRE 초안부터 씀.
  - 원천 문서를 다시 옮겨 적지 않음. R-xx는 제목, `Source: README.md §3`, 우선순위, AC만.
  - AC는 Must만 지금 씀. Should·Could는 `when tasked`로 두고, task로 만들 때 hm-setup이나 hm-change가 씀.
  - **거의 확실한 것은 묻지 않고 기본값으로 제안함.** 원천 문서나 데이터로 답이 거의 확실한 것(잘못된 단위로 들어간 값, 최신 기록으로 정리되는 중복, 대칭 쌍에서 빠진 반대 방향 행, 원천 문서의 다른 곳에 적힌 규칙)은 초안에 바로 반영하고 §7 Assumptions에 근거와 함께 `proposed`로 적음. 초안을 쓴 뒤 이 기본값들을 표 하나로 보여 주고 한 번에 확인받음. "OK"면 모두 `confirmed`, ID를 들어 고치면 그것만 반영함.
  - 질문은 진짜 모르는 것만: 아무도 적지 않은 값이나 규칙, 그럴듯한 해석이 둘 이상인 것, 원천끼리 모순되는 것. 그 자리에는 `[Q-03]` 표시를 넣고 질문을 §11에 추가함. 값을 짐작해서 넣지 않음.
  - 데이터 수치는 §4에 파일마다 몇 줄(행 수, 키, 관계, 품질 문제 개수)로만. 기존 시스템 분석은 설계에 필요한 것이라 hm-setup이 설계 단계에서 함.
  - 원천 문서의 문장이 모두 R-xx, DR, NFR, Out of scope 중 하나에 들어갔는지는 확인만 하고 대응표는 쓰지 않음.
- **질문은 모두 REQUIRE.md §11에 목록으로 정리함.** 질문마다 아래 블록이 있고, `- answer:` 칸은 비워 둠.

  ```markdown
  ### Q-08 (High) — 누락된 환승 시간
  동명 역 사이에 **공통 기본 환승 시간을 적용**해도 될까요? 된다면 몇 초인가요?
  - Why: `예솔`과 `금빛`은 이름이 같지만 데이터에 보행 시간이 없습니다 (§4).
  - Affects: R-03/AC-2, DR-02 (`[Q-08]` 표시가 있는 곳)
  - Options: A) 모든 쌍에 같은 기본값 / B) 쌍마다 운영자가 입력
  - Recommended: A. 값은 담당자 확인. 출처 문서가 동명 역을 다른 곳에서는 모두 한 역으로 다룸.
  - answer:
  ```

  - 질문 문장과 이유는 대화 언어(CHAT_LANG)로, 칸 이름(`Why`, `Recommended`, `answer`, `decision`)은 영어로 씀.
  - 처리된 질문에는 에이전트가 `- decision:` 줄을 붙임. 내 답은 고치지 않음.
- **답하는 방법은 두 가지이고, 섞어 써도 됨.**
  - 문서에서 한 번에: `- answer:` 줄에 답을 적고 "답 적었어"라고 말함. "추천대로"나 선택지 글자(A, B)만 적어도 됨.
  - 대화에서 라운드로: 서로 답을 기다리지 않는 질문을 최대 5개까지 번호를 붙여 한 번에 받고, 번호로 답함 ("1 추천대로, 2 B, 3: 15분" 또는 "전부 추천대로"). 답에서 생긴 후속 질문이 다음 라운드의 앞에 옴. 대화로 한 답도 묶음을 반영할 때 문서의 `- answer:` 줄에 옮겨 적어서, 문서가 유일한 기록이 됨.
  - 문서로 답하면 에이전트가 새로 채워진 답을 영향 순으로 처리함. 모순되거나 모호한 답, 빠진 예외에는 후속 질문 블록(`follow-up of Q-xx`)을 추가함. 나머지는 결정을 기록함. 그다음 결정된 수, 추가된 후속 질문, 남은 질문 수를 알려 줌.
- 시작할 때 묻는 모드, 세션 방식, 작업 방식은 REQUIRE.md가 생기기 전에 정해야 해서 대화로만 물음.
- **결정 트리를 따라감.** 답이 새 질문(후속 결정, 딸린 예외 상황)을 만들면 다음 라운드에서 그것부터 물음.
- **반박함.** 답이 문서, 데이터, 기존 시스템, 앞선 답과 모순되면 근거를 들어 어느 쪽이 맞는지 물음. "빠르게", "많은 사용자" 같은 모호한 답은 숫자나 입력·출력 예시를 요구함. 빈 값, 중복, 한도, 동시 처리, 권한 없음 같은 빠진 예외도 물음.
- **용어를 고정함.** 뜻이 둘이거나 동의어가 섞인 단어("회원" / "사용자" / "계정")는 하나로 정하고 정의, 대체되는 말, 예시를 남김. REQUIRE §9 용어집이 되고, 이후 설계·코드·UI·테스트 이름이 이 용어를 따름 (리뷰 체크리스트에도 포함).
- **모아서 반영함.** 대화로 받은 답은 라운드 단위로 모아서 반영함.
  - 반영 시점: 라운드마다(반영한 뒤 같은 메시지에서 다음 라운드를 물음), "그만"·"나머지 추천대로"라고 했을 때, 요약 확인 직전.
  - 반영 방법: 한 번의 수정으로 각 블록의 `- answer:`·`- decision:` 줄, `[Q-xx]` 자리의 결정 값, 바뀐 R-xx·AC·DR, 새 후속 질문 블록을 함께 넣고, 어떤 질문을 반영했는지 한 줄로 알려 줌. 고정한 용어는 §9 용어집에 넣음.
  - §11 블록이 유일한 기록이고 별도 인터뷰 로그는 없음. 세션이 끊겨 반영 못 한 답이 대화에서 보이지 않으면 그 질문을 다시 물음.
- **끝내는 기준.** `optional`이 아닌 질문에 모두 결정이 있고 열린 후속 질문이 없으면 끝남.
  - 목록에는 High와 Med 질문이 모두 들어감. 기본 질문 수를 넘는 낮은 영향의 질문은 `optional`로 표시하고, 비워 두면 추천안을 [ASSUMPTION]으로 채택함.
  - "나머지 추천대로" 또는 "그만"이라고 하면 비어 있는 질문 전부를 추천안으로 [ASSUMPTION] 처리함.
- **파고들기 모드.** "끝까지 파고들어", "꼼꼼하게 물어봐"라고 하면 Low 질문까지 목록에 넣고 `optional` 없이 모두 물음.
- **요약 확인.** 인터뷰가 끝나면(남은 `[Q-xx]` 표시 없음) 범위, 핵심 시나리오, 주요 규칙(구체적인 값), 용어, 가정을 15줄 정도로 요약해서 확인받음. 고칠 점이 있으면 새 질문으로 다루고 반영한 뒤 요약을 다시 보여 줌. 확인받으면 REQUIRE가 완성됨.

hm-change도 요청이 불명확하거나 클 때 같은 방식으로 물음.

## 설계와 셋업 (hm-setup)

설계(2단계)와 셋업(3단계)은 hm-setup 하나가 이어서 함. "설계 시작해"와 "하네스 만들어" 모두 이 스킬을 시작하고, 이미 진행된 만큼 건너뜀 (SPEC이 있고 task가 없으면 계획을 유지할지 물은 뒤 셋업부터, 셋업이 끝났으면 하네스 파일 갱신만).

- **멈추는 곳은 질문 하나.** 기술 스택과 D-xx에 답하면 DECISIONS·SPEC을 쓰고, 계획을 10줄 정도로 알려 준 뒤 멈추지 않고 셋업까지 함. 계획을 고치고 싶으면 마지막 보고 뒤에 말함. 아직 task가 시작되기 전이라 고치기 쉬움.
- **기술 스택은 항상 물음.** 백엔드, 프론트엔드(화면이 있을 때), DB·저장소, 그 밖에 해당하는 층(모바일, 큐·워커, CLI 배포)마다 D-xx 하나씩, 질문 수 상한과 별개로 물음. 선택지 2~3개에는 그 층에서 가장 널리 쓰는 선택(웹 화면이면 빌드가 있는 컴포넌트 기반 SPA와 서버 렌더링·단순 페이지 방식 둘 다)을 항상 넣고, 내가 말한 익숙한 언어·프레임워크도 넣음. HACKATHON의 "움직이는 부분 최소" 기준은 추천에만 반영하고 선택지를 줄이지 않음. 원천 문서나 내 답, 기존 코드(GREENFIELD=0)가 이미 정한 층은 묻지 않음.
- **핵심 로직도 항상 물음.** 결과가 알고리즘에 달린 계산(경로 탐색, 매칭, 순위·추천, 검색 관련도, 일정·배정, 가격, 중복 제거, 대용량 집계)마다 D-xx 하나씩, 기술 스택 다음에 상한과 별개로 물음. 이 제품에 맞춘 구체적인 질문이어야 함. 예를 들어 경로 추천이면 어떤 최단 경로 알고리즘을 어떻게 바꿀지(노드·간선이 무엇인지, 환승·대기·도보 시간을 비용에 어떻게 넣을지, 시간대를 볼지, 기준이 하나인지 시간→환승 순 같은 여러 개인지, 몇 개를 돌려주고 비슷한 경로를 어떻게 거를지, 무엇을 미리 계산할지). 선택지마다 정확도, 도메인 규칙을 얼마나 자연스럽게 담는지, 데이터 크기에서의 속도(NFR 대비), 구현·테스트 난이도를 적음. 알고리즘에 필요한 규칙("가장 좋은"의 뜻, 동점 처리)이 REQUIRE에 없으면 같은 질문에서 물음. 답은 SPEC §6에 계산마다 모델, 알고리즘과 변형, 결과 규칙, 비용, 검증 사례로 적고, 리뷰 체크리스트 4번이 이를 기준으로 봄.
- **셋업 절차는 따로 읽음.** 설계(Part A)는 SKILL.md에, 셋업(Part B)은 `references/setup.md`에 있어서 설계가 끝난 뒤에 읽음.
- **넓은 변경은 나눠서.** 리팩터가 있어야 기능이 쉬워지면 그 리팩터를 먼저 chore task로 만듦("변경을 쉽게 만든 다음, 쉬운 변경을 함"). 이름 바꾸기처럼 코드 전체를 건드리는 변경은 expand–contract로 나눔: 새 형태 추가 → 호출부를 묶음별로 옮김(묶음마다 task, 병렬 가능) → 옛 형태 삭제. 각 단계가 혼자서 테스트를 통과해서 병렬 브랜치와 충돌하지 않음. hm-change도 같은 규칙을 씀.
- **템플릿은 복사함.** SPEC, AGENTS.md, REVIEW.md, STANDARDS.md, task 템플릿, config 명령 섹션, 가드레일 예시 파일은 스킬 폴더의 `templates/`에 있고, 에이전트가 매번 새로 쓰지 않고 복사한 뒤 프로젝트에 맞는 부분만 채움.
- **고정 파일은 설치 스크립트 한 번.** `bash <hm-setup 폴더>/scripts/install.sh`가 두 스크립트, AGENTS.md(기존 파일이면 `# Harness` 섹션 추가), AGENT_FILES 진입 파일, REVIEW.md, STANDARDS.md, task 템플릿, 가드레일 예시 파일, git hook, .gitignore·.gitattributes 줄, config 명령 섹션을 넣고 `core.hooksPath`를 설정함. 있는 파일은 덮어쓰지 않음. 에이전트는 이 파일들을 직접 쓰거나 생성용 스크립트를 만들지 않고, 채울 부분(명령, 예시, task 파일)만 고침.
- **가드레일 검증은 `hm.sh selftest` 한 번.** 위반 파일이나 임시 저장소를 만들지 않음 (아래 "가드레일").
- **추적 검사는 보고만.** 셋업 때 TRACEABILITY.md를 쓰지 않음. 그 파일은 hm-audit이 씀.

SPEC에는 결정에 필요한 것만 씀: task끼리 맞춰야 하는 것과 셋업이 명령으로 바꾸는 것(§2). 세부 경로와 코드는 넣지 않고, 결정을 산문보다 정확히 담는 짧은 스키마·타입만 예외로 둠.

- **이 PC 환경에 맞추지 않음.** 설치된 런타임·도구를 확인하지 않고, 제품에 가장 맞는 스택을 고름. 버전은 에이전트가 아는 현재 안정 메이저 버전만 적고, 정확한 버전은 Task 0의 lockfile이 고정함. 예외로 저장소가 이미 고정한 버전(기존 프로젝트의 `.python-version`, `.nvmrc`, `engines`, lockfile)은 프로젝트의 결정이라 따름. 고른 런타임이 PC에 없거나 낡았으면 Task 0이 멈추고 설치 방법을 알려 준 뒤, 설치했다고 하면 이어감.
- **웹 검색 안 함.** 요구사항, 저장소, 에이전트가 이미 아는 것으로 정함. 로컬에서 확인할 수 없는 사실(최근 변경, 도구 기능, 라이선스, 지원 종료일)은 검색하지 않고 `needs check`로 표시하고, Task 0이 실제로 돌려서 확인함. 틀리면 Task 0이 멈추고 대안을 물음. 내가 요청할 때만 검색함.
- **섹션별 분량**

  | 섹션 | 쓰는 것 |
  |---|---|
  | §1 기술 스택 | 선택, 메이저 버전, 근거 |
  | §2 명령·컴포넌트 | 전부 (hm-setup이 config로 옮김) |
  | §3 데이터 모델 | 엔티티별 키, 관계, 스키마가 지킬 규칙, 결정이 걸린 열(돈, 시간, 저장 형식, 원천 데이터 변환)만. 나머지 열은 개발 때 |
  | §4 계약 | 필드와 타입, 오류 코드. 예시는 형태가 모호할 때만. **컴포넌트가 2개 이상이거나 PARALLEL>1이면 모든 항목에 예시** (양쪽을 다른 task가 만들기 때문) |
  | §6 핵심 로직 | 핵심 계산마다 모델(예: 그래프의 노드·간선·가중치), 알고리즘과 변형, 도메인 규칙이 들어가는 방식, 결과 규칙(최선의 뜻, 동점, 개수, 결과 없음), 데이터 크기에서의 비용, 손으로 확인할 수 있는 검증 사례. 그 밖의 도메인 규칙 위치는 개발 때 정함 |
  | §7 테스트 전략 | **테스트 지점(seam)**: 동작 종류마다 어디서 테스트하는지. 기존 지점 우선, 빠르게 도는 한 가장 바깥 수준, 새 지점 최소화. 개발·리뷰·디버그가 같은 기준을 씀 |
  | §8 폴더 구조 | 컴포넌트별 최상위 폴더와 테스트 위치만. 세부는 Task 0과 탐색 노트 |
  | §9 디자인 토큰 | 방향(톤, 밀도, 색 모드, 글꼴 느낌, 모서리·그림자, 모바일 우선 여부)만. Task 0이 토큰 파일을 만들고 경로를 §9에 적음 |
  | §11 추적표 | N/A. §4 항목과 §5 화면마다 Requirements를 적고, hm-setup과 hm-audit이 확인 |

  §5 화면, §10 성능, §12 보안은 그대로임.

## 요구사항 변경 (hm-change)

셋업 이후 언제든 실행할 수 있음. 데모 게이트에서 "수정 요청: …"이라고 답하면 hm-auto가 대신 실행함.

1. 요청을 `docs/changes/CR-<n>.md`에 원문 그대로 기록함 (종류: feature, change, bug, removal, non-functional, chore, spike, docs, split). chore·spike·docs는 요구사항을 바꾸지 않고 해당 종류의 task만 만듦. spike의 추천을 실제로 반영하는 건 다음 CR임.
2. 영향 분석을 함: 관련 R-xx/AC, DR, NFR, SPEC 섹션, 컴포넌트 간 계약, task, 코드.
   - Todo task: 그 자리에서 수정함.
   - 진행 중이거나 리뷰 중인 task: 브랜치를 건드리지 않고, 끝난 뒤 후속 task를 만듦. 작업 자체가 틀려지는 변경이면 Dropped + 새 task를 제안함.
   - Done task: 다시 열지 않고 새 task를 만듦. 이미 동작 중인 기능을 바꾸면 회귀 테스트를 먼저 씀.
3. 요청이 AC를 구체적인 값으로 쓸 만큼 명확하지 않으면 먼저 질문함. 해당하는 경우: 여러 뜻으로 읽힘, 값이나 예시가 없음, REQUIRE·DR·용어집·이미 나간 동작과 모순됨, 큰 변경(새 R-xx 여러 개 또는 계약 변경). 질문은 hm-req 인터뷰 방식(위)대로 라운드로 하고, CR 파일 `## Clarifications`에 기록함.
4. 영향 표(질문으로 바뀐 내용 반영), D-xx 질문, 새 task 목록을 한 번에 확인받음. 작은 변경은 한 줄 확인으로 끝남.
5. 승인되면 반영함: REQUIRE(새 ID는 다음 번호, 바뀐 AC에는 `(changed by CR-n)`, 새 용어는 §9 용어집), DECISIONS, SPEC, 새 task 파일(`Source: CR-n`, 리뷰 정책은 모드 기본값대로 되돌리기 어려운 변경만 `each`, 넓은 변경은 expand–contract로 나눔), 필요 없어진 task는 Dropped.
6. 커밋함: MERGE=local이면 INTEGRATION에 바로, pr이면 `change/CR-<n>` 브랜치로 PR.

"보안 리뷰 반영해: <파일>"이면 종류는 security임. 남은 문제마다 bug task(`Review: each`, 리뷰 파일의 재현 테스트가 첫 테스트)를 만들고, Critical·High는 먼저 시작할 수 있게 둠. Low와 개선 제안은 task로 만들지, 위험을 받아들일지(D-xx에 이유와 기한 기록) 내가 정함. 리뷰 파일의 각 문제 Status를 `Task <id>`나 `Accepted risk (D-xx)`로 바꿈.

task가 너무 커서 MAX_CONTINUE에 걸리면 "Task N 나눠줘"(split)로 쪼갬. 감사(hm-audit)에서 승인한 항목도 hm-change로 task를 만듦: 누락은 bug·feature, 구조 개선 후보와 검사 추가는 chore, 프로젝트 규칙과 안내 추가는 docs.

## 백엔드 기본 규칙

개발 시간이 늘지 않게, 새 단계나 질문 없이 해당하는 프로젝트에서만 켜지는 규칙 몇 줄로 둠.

| 항목 | 언제 | 규칙 |
|---|---|---|
| DB 마이그레이션 | DB가 있을 때 | SPEC §3에 방식과 파일 이름 규칙을 적음. 병렬 브랜치끼리 겹치지 않게 순번이 아니라 시간 기반 이름을 씀. `MIGRATE_CMD`는 `hm.sh setup`과 `hm.sh migrate`가 실행함. 병합된 마이그레이션은 고치지 않고 새로 추가함. 데이터를 지우거나 좁히는 변경은 물어봄 |
| 테스트 데이터 격리 | 항상 | 테스트마다 자기 데이터를 만들거나(고유 ID) 롤백되는 트랜잭션 안에서 돌아서, 순서와 무관하고 이미 떠 있는 컴포넌트에서도 통과함. 테스트 사이에 공용 초기화 단계를 두지 않음(느려지므로). 혼자는 통과하고 같이 돌리면 실패하는 테스트는 데이터 준비를 고침. 재시도, 순서 변경, 스킵은 금지 |
| 외부 서비스 대역 | 결제, 메일, 지도, 다른 팀 API 등을 부를 때 | SPEC §4d에 서비스, 테스트 대역(가짜 서버나 sandbox), 타임아웃, 키 이름을 적음. `test`와 `e2e`는 실제 서비스나 실제 키 없이 돌아감 |
| 중복·동시 요청 | 중복이 실제 피해인 쓰기만 (결제, 예약, 재고, 고유해야 하는 것) | SPEC §3에 해당 쓰기와 가장 단순한 방어(유니크 제약, 멱등 키, 잠금)를 적음. 테스트 하나가 같은 요청을 두 번(또는 동시에) 보내 결과가 맞는지 확인함. 나머지 쓰기는 아무것도 하지 않음 |

그 밖에 실무 기본기 9가지는 docs/STANDARDS.md "Backend baseline"에 코딩 규칙 한 줄씩으로 들어감. AGENTS.md에는 언제 읽을지만 적어서(여러 행 쓰기, 테이블·마이그레이션 추가, 외부 호출, 목록 조회, 돈·시간), 해당하는 코드를 쓸 때만 읽음. 리뷰 Standards 축의 체크리스트 11·13번이 확인함.

| 규칙 | 빠뜨리면 |
|---|---|
| 여러 단계 쓰기는 한 트랜잭션 | 중간 실패 때 반쪽 데이터 |
| DB 제약조건 (NOT NULL, FK, UNIQUE, CHECK) | 다른 경로로 깨진 데이터 유입 |
| 모든 외부 호출에 타임아웃, DB는 커넥션 풀 | 상대 하나가 느려지면 전체 멈춤 |
| 조회 상한(최대 page size), 전체 테이블 로드 금지, 필터·조인·정렬 컬럼 인덱스 | 데이터가 늘면 응답 멈춤 |
| 돈은 float 금지(정수 최소 단위나 decimal), 시간은 UTC 저장 후 표시할 때만 변환 | 정산 오차, 날짜 밀림 |
| 예외를 삼키지 않음. 로그에 요청 ID | 장애 원인을 못 찾음 |
| HTTP 의미: GET은 상태 변경 없음, 4xx·5xx 구분, 200에 오류 담지 않음 | 재호출로 데이터 변경, 모니터링 누락 |
| 바뀌는 테이블에 `created_at`, `updated_at` | 변경 이력 추적 불가 |
| 커넥션, 파일, 스트림은 오류가 나도 반드시 정리 | 몇 시간 뒤 자원 고갈 |

배포, CI, 롤백, 캐시 무효화, API 버전 관리, 큐 재시도, 관측성 도구, 느린 작업의 비동기 처리, 감사 로그, soft delete는 하네스 기본에 넣지 않음. 필요하면 hm-setup의 D-xx나 hm-change로 다룸.

## 보안

보안은 단계마다 들어가 있지만, 초반 단계(1~3)는 시간이 거의 들지 않게 기본값으로 처리하고, 무거운 작업(공격 표면 전체 파악, 보안 테스트, 스캔 도구 추가)은 hm-security로 미룸.

| 단계 | 하는 일 | 초반 비용 |
|---|---|---|
| 1 hm-req | 보안 질문은 최대 하나로 묶음: 누가 누구의 데이터를 보고 바꿀 수 있는지, 로그인 방식, 민감하거나 규제받는 데이터. 결제, 건강, 미성년자, 다른 시스템의 인증 정보, 규제 언급이 없으면 `optional`이고, 해당 없으면 묻지 않음. 기본 SEC-xx(예: "DB가 유출돼도 비밀번호를 알아낼 수 없고, 같은 비밀번호라도 저장값이 다르다")는 묻지 않고 [ASSUMPTION]으로 적고, 요약 확인 때 보여 줌 | 질문 0~1개 |
| 2 hm-setup (설계) | 보안은 "Defaults I chose"에 넣고 묻지 않음. 로그인 방식처럼 만들 것이 달라지는 경우만 D-xx로 물음. SPEC §12는 짧게 씀: 핵심 위협 몇 개(FULL 5개, HACKATHON 3개까지)와 영역별 통제 한 줄. 기본 규칙으로 충분하면 `baseline`이라고만 씀. 비밀번호 해시(Argon2id 우선, 없으면 scrypt·bcrypt, 파라미터는 OWASP 기준)는 질문이 아니라 기본값이라 레인보우 테이블로 깰 수 없음. 스캔 도구는 의존성 검사 하나만 고름 | 질문 0~1개 |
| 3 hm-setup (셋업) | docs/STANDARDS.md에 보안 기본 규칙, AGENTS.md에 금지 사항과 "비밀번호·인증 정보·입력으로 만드는 쿼리·접근 판단 코드를 쓰기 전에 읽으라"는 안내를 넣음. Task 0은 환경 변수로 비밀값 읽기, `.env` 무시, 비밀값 검사만 함. 보안 헤더, 기본 거부 같은 공통 통제는 그런 진입점을 처음 만드는 task가 연결함 | 거의 없음 |
| 4 hm-dev | SEC-xx가 걸린 task는 그것을 증명하는 테스트가 완료 기준임. `hm.sh security`는 의존성을 추가하거나 SEC-xx가 걸린 task만 돌림 | 해당 task만 |
| 5 hm-review | 리뷰 Standards 축의 체크리스트 12번이 SPEC §12와 STANDARDS.md 기본 규칙을 기준으로 봄 |
| 6-3 hm-security | 별도 세션에서 보안 테스트를 만들고 검사한 뒤 보안 리뷰를 씀 (아래) |
| 6-2 hm-audit | SEC-xx마다 테스트나 보안 리뷰가 있는지, 마지막 보안 리뷰 이후 민감한 부분이 바뀌었는지, task 없이 남은 문제가 있는지 봄 |

### hm-security ("보안 점검해")

리뷰처럼 코드를 쓰지 않은 별도 세션에서 돌림. 제품 코드는 고치지 않음. 공격 대상은 이 worktree에서 띄운 자기 컴포넌트뿐이고, 운영·공용·외부 시스템이나 실제 사용자 데이터에는 절대 시도하지 않음.

1. `security/<n>` 브랜치(필요하면 worktree)를 만듦. SECURITY_CMD에 정적 분석이나 이력 비밀값 검사가 없으면(처음 돌 때) 도구를 먼저 추천하고 물어봄.
2. 공격 표면을 SPEC이 아니라 코드에서 직접 뽑음: 모든 진입점(라우트, CLI, 메시지 소비자, 업로드, 웹훅), 인증·권한, 민감한 데이터가 있는 곳. SPEC에 없는 진입점이나 SPEC보다 약한 보호는 그 자체로 문제임.
3. `hm.sh security`와 git 이력 전체 비밀값 검사를 돌리고, 결과마다 실제 문제 / 여기선 악용 불가 / 오탐을 이유와 함께 분류함.
4. 영역별 보안 테스트를 씀: 비밀번호 저장(같은 비밀번호 두 계정의 저장값이 다른지, 해시 형식과 파라미터, DB·로그·응답에 평문이 없는지), 로그인 남용, 접근 제어(세션 없이, 다른 사용자로, 낮은 권한으로), 인젝션, XSS·CSRF·CORS·헤더·SSRF, 파일, 비밀값과 설정, 로그와 오류, 컴포넌트 사이, 의존성, 데이터 보호, 자원 남용.
   - 통과하는 테스트는 회귀 테스트로 커밋함.
   - 실패하는 테스트는 커밋하지 않음 (커밋하면 모두의 `test`가 깨짐). 리뷰 파일의 해당 문제에 코드를 넣어 수정 task가 그 테스트로 시작하게 함.
5. 이전 리뷰에서 남은 문제를 다시 확인함.
6. `docs/security/review-<k>.md`를 씀: 판정(Pass / Pass with issues / Fail), 요약, 공격 표면, 스캔 결과, 영역별 결과, 문제(심각도, 위치, 증거, 영향, 개선 방향, 재현 테스트), 이전 문제 상태, 개선 제안, 추가한 테스트. Critical·High는 실패 테스트나 구체적인 재현이 있어야 함. 증명 못 한 의심은 개선 제안에 "확인 필요"로 둠.
7. 테스트와 리뷰를 커밋함. 병합은 직접 하지 않고 "Merge branch security/<n>."(hm-dev)을 안내함. 그다음 "보안 리뷰 반영해: <파일>"(hm-change)로 문제를 task로 만들고, 고친 뒤 다시 "보안 점검해"로 확인함.

| 심각도 | 기준 |
|---|---|
| Critical | 인증 없이 또는 아무 사용자나 가능하고, 계정 탈취·다수 사용자 데이터·코드 실행·비밀번호 복원으로 이어짐 |
| High | 전제 조건이 필요하거나, 한 사용자의 데이터·비밀값·통제 하나가 뚫림 |
| Medium | 다른 결함을 키우는 방어 누락, 제한된 노출 |
| Low | 강화, 모범 사례, 정보 |

## 자동 실행 (hm-auto)

1~3단계(요구사항, 설계, 셋업)는 수동으로 하고, 4~5단계(개발, 리뷰, 리뷰 반영, 병합)를 Codex 대화창 하나에서 자동으로 돌림. 수동 흐름은 그대로 동작하고, 이건 그 위에 얹는 선택 사항임.

### 구조

| 역할 | 누가 | 하는 일 |
|---|---|---|
| 오케스트레이터 | 대화창의 Codex (hm-auto 스킬) | 다음 단계를 묻고, 서브에이전트를 띄우고(최대 PARALLEL개), 결과를 확인하고, 데모·질문을 나에게 전달함. 코드나 문서는 직접 고치지 않음 |
| 작업자 | 단계마다 새 서브에이전트 (대화 내용을 물려받지 않음) | `Use the <skill> skill. <트리거 문장> <작업 위치>`로 기존 스킬을 그대로 실행함. task마다 자기 worktree에서만 작업함 |
| 상태 판단 | `scripts/harness-state.sh` (bash, 에이전트를 호출하지 않음) | task 파일, 브랜치, 리뷰 파일만 보고 다음 단계와 성공 여부를 결정함. 동시 실행 수, 의존성, 병합 한 번에 하나, worktree 포트 배정을 지킴. 오케스트레이터의 기억에 의존하지 않음 |

### 명령 (대화창에서)

| 입력 | 동작 |
|---|---|
| "자동으로 진행해" | 모든 task (`all`). batch task가 병합되어 있으면 마지막에 review all까지 |
| "Task 2 자동으로" / "Task 1~3 자동으로" / "Task 4,7 자동으로" | 해당 task만 (`2`, `1-3`, `4,7`) |
| "전체 리뷰 자동으로" | review all만 (`review-all`). 마지막 전체 리뷰 이후 병합된 것만 봄 |
| "데모 확인 없이 자동으로" | 데모 확인 게이트를 끄고 실행 ("확인 필요" 항목은 한 줄로 알려 줌) |
| "자동 실행 상태 보여줘" | task별 상태, 리뷰 정책, 위치(int/local/remote), 다음 동작 표 |
| "자동 실행 계획 보여줘" | 현재 상태 기준 task별 다음 단계 (아무것도 바꾸지 않음) |

데모 게이트에서는 "계속", "중단", "수정 요청: <내용>" 중 하나로 답함 (같은 뜻이면 어느 언어든 됨). "수정 요청"은 hm-change로 새 task를 만듦. 데모가 없는 task(chore, spike, docs)에서는 멈추지 않음.

스크립트를 직접 실행할 수도 있음 (Windows PowerShell에서는 Git Bash 경로를 직접 지정):

```
bash scripts/harness-state.sh status
bash scripts/harness-state.sh plan all
bash scripts/harness-state.sh worktree 3
& "C:\Program Files\Git\bin\bash.exe" scripts/harness-state.sh status
```

| 스크립트 명령 | 용도 |
|---|---|
| `status` | 상태 표 (브랜치를 가로질러) |
| `plan <target>` | task별 다음 단계 (변경 없음) |
| `worktree <id>` | task(또는 `review-3` 같은 보조 worktree)의 경로, 브랜치, 기준 브랜치, PORT_OFFSET, 막고 있는 의존 task |
| `run-begin <target> [--no-demo]` | 검증, lock, 실행별 카운터 초기화. `--no-demo`면 데모 확인 없이 진행 |
| `next [--all]` | 단계 하나를 내줌 (`action`, `step`, `task`, `dir`, `skill`, `prompt`, `log`). `--all`이면 지금 시작할 수 있는 단계를 한 번에 모두 내줌 (블록 사이에 `--` 줄, 상태는 한 번만 읽음). 마지막 블록은 더 내줄 게 없으면 `action=wait`, 끝이면 `done`, 사람이 필요하면 `stop` |
| `check <step> [--next]` | 그 단계의 결과 확인 (`ok` / `continue` / `needs_user`). `--next`면 `ok`·`continue` 뒤에 `--`와 `next --all` 결과까지 한 번에 출력하고, 데모 확인이 필요한 task는 다음 단계를 내주기 전에 스스로 hold함 |
| `notes` | 탐색 노트 상태 (`fresh` / `stale` / `missing` / `skip`), 경로, INTEGRATION 커밋 |
| `hold <id> [이유]` / `release <id>` | 그 task에 단계를 내주지 않음 / 다시 내줌 (데모 답을 기다리는 동안). `next`는 hold된 task만 남으면 `action=wait`, `held=<id들>` |
| `run-end` | lock 해제, 대기 중 단계와 hold 정리 |

target: `<id>`, `<id>,<id>`, `N-M`(숫자 ID), `all`, `review-all`. 환경 변수: `MAX_CONTINUE`(기본 2), `MAX_REREVIEW`(기본 1). 종료 코드: 0 정상, 1 사용법·사전조건 오류, 3 사람 필요.

### 실행 루프

1. 슬롯 채우기: `next --all` 한 번으로 시작할 수 있는 단계를 모두 받아 서브에이전트를 띄움.
2. 아무 서브에이전트나 끝나면 로그를 저장하고 `check <step> --next`를 실행함. 결과 확인과 다음 단계 받기가 한 번의 호출로 끝나서, 상태를 다시 읽는 횟수가 줄어듦 (Windows에서 호출마다 git을 여러 번 띄우므로 이게 실행 시간을 크게 좌우함).
3. `check`가 질문(`needs_user`)을 돌려준 경우에만 1로 돌아가 다시 채움. 나머지는 2에서 이미 채워졌으므로 다음 서브에이전트가 끝나기를 기다림.
4. 데모 확인이나 질문은 그 task만 멈춤 (데모는 `check --next`가 그 task를 hold함, 질문은 그 단계가 대기 중으로 남음). 다른 task는 계속 돌고, 대기 중인 task는 슬롯을 차지하지 않음. 더 돌릴 게 없을 때 열린 데모·질문을 한 번에 물어봄. 그 전에 답해도 됨.
5. 데모에 답하면 `release <id>`로 그 task를 다시 진행함. "수정 요청"이면 hm-change가 끝날 때까지 새 단계를 내주지 않음 (INTEGRATION에 커밋하므로). 그동안 끝난 단계는 `--next` 없이 `check`만 함.
6. 실행 시작 때 탐색 노트(`artifacts/notes/codebase.md`)가 없거나 INTEGRATION보다 오래됐으면, 서브에이전트 하나가 코드 지도(컴포넌트별 진입점, 폴더 역할, 주요 모듈, 요청 흐름, 테스트 위치, 관례, 주의점, 150줄 안팎)를 쓰거나 바뀐 부분만 고침. dev 서브에이전트는 이 노트를 먼저 읽고 각자 처음부터 탐색하지 않음. 새 프로젝트에서 코드가 아직 없으면 건너뜀. "탐색 노트 갱신해"로 따로 실행할 수도 있음.

### task 하나의 흐름

1. 상태가 Done/Dropped면 건너뜀. Todo이고 의존 task가 모두 병합되었으면 "Start Task <id>." (worktree 경로와 PORT_OFFSET을 함께 줌), In Progress면 "Continue Task <id>."
2. dev가 끝나면 task 브랜치의 상태를 확인함.
   - In Review: 성공. feature·bug이고 데모 게이트가 켜져 있으면 데모를 보여 주고 답을 기다림. chore·spike·docs는 요약(spike는 추천)만 한두 줄 알려 주고 계속함
   - Done: 실패 (dev는 Done을 설정할 수 없음)
   - In Progress이고 새 `wip(task-<id>)` 커밋이 있음: 컨텍스트 소진. 새 서브에이전트로 Continue (최대 MAX_CONTINUE번)
   - In Progress인데 wip 커밋이 없음: 질문. 대화창에 보여 주고, 내 답을 같은 서브에이전트에 전달한 뒤 다시 확인
   - 브랜치에 커밋이 없음: 사전조건 실패 또는 질문. 멈춤
3. `Review: each`면 새 서브에이전트로 리뷰함. 새 리뷰 파일이 생겼는지, `Commit:`이 브랜치 끝과 같은지 확인하고 Verdict와 Blocker 여부를 읽음
4. 새 서브에이전트로 리뷰 반영 (`Apply these review comments: <리뷰 파일>`)
   - Blocker 없음: Done 후 병합(local)되었거나 push(pr)되었어야 함
   - Blocker 있음: In Review로 남고, 리뷰한 커밋 뒤에 `fix(...)` 커밋이 있어야 함. 그다음 재리뷰와 반영을 최대 MAX_REREVIEW번 반복
5. `Review: batch`면 리뷰 없이 "Merge Task <id>."로 병합함. INTEGRATION에서 In Review 상태로 남아 있다가 review all에서 Done이 됨
6. `all`에서 batch task가 병합되어 있으면, 모든 task가 끝난 뒤 review all → 반영 → (Blocker면 fix 브랜치 재리뷰) → 병합

병합 단계(apply, merge, apply-all, merge-all)는 한 번에 하나만 돔. 메인 작업 트리와 INTEGRATION을 건드리기 때문임.

재개 규칙 (항상 파일과 git에서 계산함):
- In Review(each)인데 최신 `artifacts/review/` 파일이 브랜치의 `docs/reviews/`에 없음: 그 파일로 반영부터
- 마지막으로 반영한 리뷰에 Blocker가 있음: 재리뷰부터
- 브랜치에서 Done인데 병합 안 됨: 병합부터 (pr이면 push되어 있으면 팀 병합 대기)
- 그 외: 새 리뷰
- 작업 위치(worktree)가 dirty면 그 task의 다음 단계를 거부함. 단, In Progress task를 Continue하는 경우만 허용 (질문으로 멈추면 작업이 커밋되지 않은 채 남기 때문)

### 멈추는 경우

| 사유 | 의미 | 할 일 |
|---|---|---|
| 질문 (In Progress, wip 없음) | dev가 결정이 필요함 | 대화창에서 답하면 이어감. 나중에 재개하면 Continue부터 |
| 브랜치에 커밋 없음 | 사전조건 실패 또는 시작 전 질문 | 로그 확인, 원인 해결 후 재개 |
| dev가 Done으로 설정 | 역할 위반 | 브랜치에서 In Review로 되돌린 뒤 재개 |
| MAX_CONTINUE 초과 | 계속 컨텍스트 소진 | Notes for Next Session 확인, "Task N 나눠줘"(hm-change) 검토 |
| MAX_REREVIEW 초과 | Blocker가 반복됨 | 최신 리뷰 확인, 결정 후 재개 (재리뷰부터) |
| 리뷰 파일 없음 / Verdict 못 읽음 / 다른 커밋을 리뷰함 | 리뷰 단계 실패 | 로그 확인 후 재개 (다시 리뷰) |
| 리뷰 반영 안 됨 | 반영 중 질문 또는 실패 | 답하거나 해결 후 재개 (같은 파일로 다시 반영) |
| 병합 안 됨 | 통합 중 로직 충돌 또는 테스트 실패 | 로그 확인, 결정 후 재개 |
| 팀 병합 대기 (pr) | push한 브랜치가 PR 병합을 기다림 | PR 병합 후 재개 |
| 의존 task 미병합 | 지금 돌릴 수 있는 task가 없음 | 막고 있는 task를 먼저 끝내거나 병합 |
| 작업 트리 dirty | 세션이 커밋 안 된 변경을 남김 | 해당 worktree에서 `git status` 확인 후 정리 |
| lock held | 다른 자동 실행이 진행 중 | 실제로 없으면 `run-end` 후 재개 |
| 데모 확인에서 "중단" | 내가 멈춤 | 다시 "자동으로 진행해". 답하지 않은 데모는 보고에 나옴. 재개하면 그 task의 리뷰·병합으로 넘어가므로 먼저 확인함 |

재개는 언제나 같은 명령("자동으로 진행해")임. 상태가 파일과 브랜치에 있어서 잃는 것이 없음.
각 단계의 서브에이전트 마지막 메시지는 `artifacts/runs/<run>/<NN>-<action>-<task>.md`에 저장됨.

### 스크립트가 의존하는 규칙

| 규칙 | 정의한 곳 |
|---|---|
| `.harness/config`의 `MODE`, `INTEGRATION`, `MERGE=local\|pr`, `REMOTE`, `PARALLEL`, `WORKTREES`, `WORKTREE_DIR`, `PORT_STEP` | hm-req |
| task 파일 `docs/tasks/<id>.md`, 줄 `- Status:`(Todo, In Progress, In Review, Done, Dropped), `- Type: feature\|bug\|chore\|spike\|docs`(없으면 feature, 데모는 feature·bug만), `- Review: each\|batch`, `- Depends on: <id>, <id>\|none`. ID는 `[A-Za-z0-9][A-Za-z0-9._-]*`, `_`로 시작하는 파일은 무시 | hm-setup B2, task 템플릿 |
| task 브랜치 `task/<id>`, review all 수정 브랜치 `fix/review-all-<k>` | hm-dev |
| 리뷰 파일 `<메인 작업 트리>/artifacts/review/task-<id>-review-<k>.md`, `review-all-<k>.md`. 반영본은 브랜치의 `docs/reviews/` | REVIEW 템플릿, hm-dev |
| `Verdict: APPROVE` / `Verdict: CHANGES REQUESTED` 줄, `Commit: <sha>` 줄, Findings 행 `\| RV-n \| Blocker \| ...` (Spec·Standards 어느 표에 있어도 됨) | REVIEW 템플릿 Output |
| `wip(task-<id>): ...`는 컨텍스트 소진만 뜻함. 질문할 때는 wip 커밋을 하지 않음. 리뷰 수정 커밋은 `fix(...)` | hm-dev, AGENTS.md |
| 리뷰 반영(hm-dev)은 리뷰 파일 경로를 입력으로 받음. "Merge Task <id>." / "Merge branch fix/review-all-<k>."로 병합만 할 수 있음 | hm-dev |
| worktree `<WORKTREE_DIR>/<이름>`, 포트 오프셋은 그 안의 `.harness/local`의 `PORT_OFFSET` | AGENTS 템플릿, hm-dev |
| 탐색 노트 `<메인 작업 트리>/artifacts/notes/codebase.md`, 첫 줄 `Commit: <sha>` | hm-auto |
| `.harness/config` 형식: 한 줄에 `KEY=value`, 값은 줄 끝까지 그대로, `#`으로 시작하면 주석 (hm.sh, harness-state.sh가 읽음) | hm-req `templates/config.template` |
| `.harness/guardrail-samples` 형식: 한 줄에 `<종류>: <예시>`, 종류는 `skip`, `selector-deny`, `selector-allow`, `secret`, `secret-allow` (hm.sh selftest가 읽음) | hm-setup B3, 예시 템플릿 |
| 명령 키 `INSTALL_CMD`, `MIGRATE_CMD`, `TEST_CMD`, `LINT_CMD`, `TYPECHECK_CMD`, `FORMAT_CMD`, `E2E_SETUP_CMD`, `E2E_CMD`, `DEV_CMD`, `LOAD_CMD`, `BENCH_CMD`, `SECURITY_CMD`, `SECRET_PATTERN`, `TEST_DIRS`, `E2E_DIRS`, `SKIP_PATTERN`, `SELECTOR_PATTERN`, `LOAD_TARGET_USERS`, `LOAD_LEVELS`, `LOAD_DURATION`, `SERVICE`. `hm.sh test`·`e2e`에 준 인자는 명령의 `"$@"` 자리에 들어감 | hm-setup B5, config 명령 템플릿 |
| 컴포넌트 키 `COMPONENTS`, `<c>_DEV`, `<c>_PROD`, `<c>_PORT`(기본값), `<c>_HEALTH`, `UP_CMD`, `DOWN_CMD` (hm.sh가 읽음) | hm-setup B5, config 명령 템플릿 |

### 설치 (Codex)

스킬 폴더를 Codex 스킬 경로로 복사함. setup에서 스킬을 고치면 같은 명령으로 다시 복사해야 함 (이 저장소 루트에서, Git Bash). Claude Code도 쓰면 `~/.claude/skills/`에도 같은 방식으로 복사함:

```
for d in harness-skills/hm-*; do rm -rf ~/.codex/skills/"${d##*/}"; cp -r "$d" ~/.codex/skills/; done
for d in harness-skills/hm-*; do rm -rf ~/.claude/skills/"${d##*/}"; cp -r "$d" ~/.claude/skills/; done
```

실제 에이전트로 쓰기 전에 확인할 것:
- Codex의 multi-agent 기능이 켜져 있어야 함 (`codex features list`에서 `multi_agent  stable  true`)
- 서브에이전트가 파일을 쓰고 `bash`, `git`을 실행해야 함. worktree는 저장소 밖(WORKTREE_DIR)에 만들어지므로 Codex sandbox가 그 경로에도 쓸 수 있어야 함 (`workspace-write`에 경로 추가, 또는 그 이상). 승인 정책에 따라 서브에이전트의 명령 승인 요청이 대화창에 뜸
- MERGE=pr이면 git이 REMOTE에 push할 수 있어야 함 (인증)
- 처음에는 데모 게이트를 켠 채 Task 하나(`Task 0 자동으로`)로 시험하고, 그다음 PARALLEL을 올림
