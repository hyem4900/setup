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
