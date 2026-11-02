# 변경 이력

## v4 (v3에서 바뀐 것)

| 항목 | v3 | v4 |
|---|---|---|
| 상태 저장 | TASKS.md + PROGRESS.md 한 파일 | task마다 `docs/tasks/<id>.md`. 상태도 그 안에 있음. 병렬 브랜치끼리 충돌하지 않음 |
| 작업 단위 | 한 브랜치에 선형 커밋, 태그로 범위 구분 | task마다 브랜치 `task/<id>` (+ 선택적으로 worktree). 리뷰 범위는 브랜치 diff와 리뷰 파일의 `Commit:` |
| 동시 작업 | 한 번에 한 task | PARALLEL개까지 동시에 진행. 병합만 한 번에 하나씩 |
| 통합 | 같은 브랜치라 통합 단계 없음 | 리뷰 반영 단계(hm-dev)가 INTEGRATION에 병합(MERGE=local)하거나 push 후 팀 PR로 병합(MERGE=pr) |
| 실행 명령 | Makefile (GNU make 필요) | `bash scripts/hm.sh <명령>`. 스택별 명령은 `.harness/config`의 한 줄씩. git과 bash만 필요 |
| 서버 | 서버 하나(PORT, DEV_CMD, /healthz) | 컴포넌트 목록. 각자 명령·포트·health check를 가짐. `hm.sh`가 순서대로 띄우고 프로세스 트리째 정리함 |
| 화면 | 브라우저만, HAS_SERVER=1 필요 | 브라우저·모바일·데스크톱. HAS_SERVER와 무관 |
| task 수 | 모드별 고정 (FULL 5, HACKATHON 3) | 모드는 처음 계획의 크기만 정함. 언제든 hm-change로 추가 |
| 질문·결정 상한 | 고정 | 기본값. 중요한 게 남으면 계속할지 물어봄 |
| 요구사항 변경 | 경로 없음 | hm-change (CR 기록 → 영향 분석 → 필요하면 질문 → 한 번 확인 → 문서·task 갱신) |
| 리뷰 대상 | MODE + `[core]` 표시 | task별 `Review: each / batch` |
| task 종류 | 모든 task가 기능 개발 (테스트 먼저, AC, 데모) | `Type: feature / bug / chore / spike / docs`. 종류마다 진행 방식과 완료 기준이 다르고, 데모는 feature·bug만 |
| 언어 | 대화 한국어, 문서 영어 고정 | `CHAT_LANG`, `DOC_LANG`. 스크립트가 읽는 값과 코드는 항상 영어 |
| 에이전트 | AGENTS.md만 | AGENTS.md + `AGENT_FILES`(기본 CLAUDE.md)가 AGENTS.md를 가리킴 |
| worktree 분리 | 포트만 | 포트 + `HM_SLOT`으로 DB·캐시·큐 이름 등도 worktree마다 분리 |
| E2E 선택자 | test-id만 | 선택자 정책 `test-id` / `test-id+role` / `none` (2단계 결정) |
| 보안 | 리뷰 체크리스트 한 줄 | 보안 요구사항(SEC-xx), SPEC §12 위협 모델·통제, docs/STANDARDS.md 기본 규칙, 커밋 전 비밀값 검사, `hm.sh security` 스캔, hm-security(보안 테스트 + 보안 리뷰) |
| 개발 루프 | 테스트를 먼저 다 쓰고 구현 | 테스트 하나 실패 → 최소 구현 → 다음 테스트 (tracer bullet). 반복 중에는 고친 테스트만 돌리고, 끝에 전체 |
| 리뷰 | 체크리스트 하나 | Spec 축(요청한 것을 만들었나)과 Standards 축(이 프로젝트 방식대로 만들었나)을 따로 보고 따로 보고함. 코드 냄새 기본 목록 포함 |
| 코딩 기준 | AGENTS.md에 전부 | docs/STANDARDS.md. AGENTS.md에는 언제 읽을지만 적음. 반복되는 지적은 검사(기계적)나 Project rule(판단)로 바꿈 |

## v4.1 (스킬 축약 때 지운 규칙)

개발 세션이 매번 읽는 파일(AGENTS 템플릿, hm-dev SKILL.md, tdd.md)에서 "다른 파일에 이미 있거나, 적지 않아도 모델이 그렇게 하는" 규칙을 지움. 실제 실행에서 빠뜨리는 행동이 보이면 이 표를 보고 되살림.

| 지운 규칙 | 있던 곳 | 지금 있는 곳 / 지운 이유 |
|---|---|---|
| 계약·데이터 모델 변경 금지, SPEC §1 밖 의존성 추가 금지 | AGENTS Forbidden | AGENTS "Ask the user when"에 같은 내용 |
| SESSION_PER_TASK별 두 번째 task 허용 조건 | AGENTS Forbidden | hm-dev 사전조건 3 |
| 병합된 마이그레이션 수정 금지, 데이터를 지우거나 좁히는 마이그레이션은 질문 | AGENTS Forbidden | STANDARDS.md Backend baseline |
| 실제 외부 서비스 호출 테스트, 다른 테스트 데이터에 의존하는 테스트 금지 | AGENTS Forbidden | tdd.md "Test doubles", "sets up its own data" |
| 같은 테스트 3번 실패 + 디버그 실패 시 질문 | AGENTS Ask when | hm-dev workflow → debug.md가 언제 물을지 정함 |
| 답을 Decisions during development에 기록하고 테스트 추가 | AGENTS Ask when | hm-dev workflow DQ 규칙 |
| "Markdown 굵게·코드만, HTML·색 코드 금지" | AGENTS 질문 양식 | 모델 기본 동작 |
| tracer bullet 설명, 디버그 절차 괄호 요약 | AGENTS Task workflow 2 | tdd.md, debug.md 본문 |
| 혼자 통과·같이 실패하는 테스트는 데이터 준비를 고침 | AGENTS Task workflow 4 | tdd.md |
| 엣지케이스·알고리즘 예시 목록 (각 9개 → 4~5개) | AGENTS Ask when | 규칙은 유지, 예시만 줄임 |
| 데모 설명의 화면/서비스/명령별 하위 항목 | AGENTS Report format | 모델이 종류에 맞게 씀 |
| SEC-xx 테스트 예시 괄호 | AGENTS DoD | hm-security, STANDARDS Security baseline |
| WORKTREES=1/0 설명 2줄 → 1줄 | AGENTS Branches | hm-dev 사전조건 4, harness-state.sh start-check |
| "Anti-patterns" 섹션 (구현 결합, 동어반복, 수평 슬라이싱) | tdd.md | "What a good test is"가 긍정형으로 같은 내용. 리뷰 체크리스트 10번 |
| "몇 사이클마다 건드린 파일 실행, 전체는 끝에" | tdd.md | AGENTS Commands |
| Inputs 표, 하네스 없이 시작하는 절차, "Other skills"·"Files I name" | hm-dev SKILL.md | references/develop-without-harness.md, references/no-harness.md (하네스가 있으면 AGENTS.md) |
| Start Task 사전조건 중 브랜치·의존·PARALLEL·dirty 검사 | hm-dev SKILL.md, AGENTS Ask when | `harness-state.sh start-check <id>` |
| Inputs 표(하네스 없을 때의 대체 파일), "Other skills"·"Files I name" | hm-review, hm-audit, hm-load-test, hm-security, hm-change SKILL.md | 각 스킬의 references/inputs.md, references/no-harness.md (하네스가 있으면 AGENTS.md). 본문에는 하네스가 있을 때 읽는 파일 한 줄만 남김 |
| Rules 4줄(읽기 전용, 테스트 직접 실행, 데모, config 읽기), Where to run 절, "두 축 분리·RV 번호·파일 쓰고 출력" | hm-review SKILL.md | docs/REVIEW.md(템플릿)의 Rules·Where to run·Checklist·Output. 금지 git 명령 한 줄은 템플릿 Rules로 옮김. 하네스 없을 때의 detached worktree는 references/inputs.md |
| Task workflow, Report format, Definition of Done (4.2KB) | AGENTS 템플릿 | hm-dev SKILL.md 끝부분. hm-dev만 쓰는 내용이라 리뷰·변경·보안·감사 세션이 읽지 않게 함. 기존 프로젝트의 AGENTS.md에 남은 사본은 두어도 되고(hm-dev 것이 우선) 지워도 됨. 하네스 섹션 판별 표시는 `## Task workflow`에서 `Project profile: see .harness/config` 줄로 바뀜 (install.sh, hm-setup) |
