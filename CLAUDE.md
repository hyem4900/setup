# 하네스 스킬 저장소

에이전트가 요구사항부터 리뷰까지 단계별로 진행하게 만드는 스킬 모음입니다.
에이전트가 일하고, 사람은 단계 사이에서 확인만 합니다.

## 무엇이 어디에

| 파일 | 내용 |
|---|---|
| `FLOW.md` | 전체 흐름 설명. 사람이 읽는 기준 문서 |
| `CHANGELOG.md` | 버전 사이에 바뀐 것 (v3 → v4 비교표) |
| `harness-skills/hm-*/SKILL.md` | 단계별 스킬 9개. hm-dev는 개발·리뷰 반영·병합을 함께 맡음 |
| `harness-skills/hm-*/references/`, `hm-req/templates/` | 일부 경우에만 읽는 내용: hm-dev의 `tdd.md`(테스트 먼저 루프)·`debug.md`(디버그 절차)·`review-and-merge.md`(리뷰 반영·병합), hm-setup의 `setup.md`(셋업, Part B)·`no-require.md`(REQUIRE 없이 시작), hm-auto의 `stop-reasons.md`(멈춤 사유 표), hm-req의 `interview.md`(§11 질문 양식과 인터뷰 절차)와 REQUIRE 양식·config 양식 (hm-setup도 읽음) |
| `harness-skills/_shared/`, `harness-skills/sync-shared.sh` | 여러 스킬이 같이 쓰는 문단의 원본: `question-format.md`(질문 양식), `no-harness.md`(하네스 없이 돌 때의 규칙·기본값). `sync-shared.sh`가 각 스킬의 `references/`로 복사함. **복사본을 직접 고치지 말고** 원본을 고친 뒤 sync. 스킬 본문에 남긴 "Other skills"·"Files I name" 두 단락은 짧고 중요해서 일부러 각 스킬에 그대로 둠 |
| `harness-skills/hm-setup/templates/` | hm-setup이 프로젝트로 복사하는 템플릿 (SPEC, AGENTS, REVIEW, STANDARDS, task 파일, config 명령 섹션, 가드레일 예시). 형식을 바꾸면 스킬 본문과 함께 고침 |
| `harness-skills/hm-setup/scripts/install.sh` | 셋업 때 고정 파일(스크립트, 템플릿, hook, gitignore·gitattributes 줄, config 명령 섹션)을 한 번에 넣는 설치 스크립트. 있는 파일은 덮어쓰지 않음 |
| `harness-skills/hm-setup/scripts/harness-state.sh` | task 파일·브랜치·리뷰 파일로 "다음에 뭘 할지"를 판단하는 스크립트 (자동 실행, worktree 경로·포트 배정) |
| `harness-skills/hm-setup/scripts/test-harness-state.sh` | `harness-state.sh`를 임시 저장소에서 검증하는 테스트. 이 저장소 전용이며 프로젝트로 복사되지 않음. 스크립트나 "스크립트가 의존하는 규칙"을 고치면 실행 (Windows에서 몇 분 걸림) |
| `harness-skills/hm-setup/scripts/hm.sh` | 프로젝트의 하네스 명령 (setup, test, e2e, security, check, selftest, dev-bg 등). 명령 내용은 `.harness/config`에서 읽음. 컴포넌트 기동·health check·종료 포함 |
| `setup.md` | 하네스와 별개인 예전 개인 설정 메모 |

## 흐름 한눈에

```
1 요구사항 → 2 설계 → 3 셋업 → 4 개발 (task마다 브랜치) → 5 리뷰 → 리뷰 반영 · 병합 → 6 성능 · 보안 · 누락 검토
                               └──── 4~5는 hm-auto로 자동 실행 가능 (PARALLEL개 동시) ────┘
                     셋업 이후 언제든: 요구사항 추가·변경 → hm-change → 새 task
```

| 단계 | 스킬 | 이렇게 말하면 시작 |
|---|---|---|
| 1 | hm-req | "요구사항 정리 시작해" |
| 2~3 | hm-setup | "설계 시작해" / "하네스 만들어" (설계와 셋업을 이어서 함) |
| 4 | hm-dev | "Start Task N." (하네스 없이: "개발해: …") |
| 5 | hm-review (별도 세션) / hm-dev (개발 세션) | "Review Task N." / "이 브랜치 리뷰해" / "리뷰 반영해: <파일>" / "Merge Task N." / "Merge branch <브랜치>." |
| 6 | hm-load-test / hm-security / hm-audit | "부하 테스트 해" / "보안 점검해" / "누락 검토해" |
| 4~5 자동 | hm-auto | "자동으로 진행해" |
| 디버그 | hm-dev | "디버깅해: …" / "원인 찾아줘: …" (bug task에서 개발 중에 자동으로 씀) |
| 변경 | hm-change | "요구사항 추가해: …" / "버그 등록해: …" / "보안 리뷰 반영해: <파일>" / "Task N 나눠줘" |

## 고칠 때 지킬 것

- 스킬 파일이 기준입니다. 동작이 바뀌면 `FLOW.md`도 같이 고칩니다.
- 스킬은 다른 스킬을 실행하거나 그 절차를 빌려 오지 않습니다. 사용자가 이름으로 요청했거나 SPEC·DECISIONS에 기록된 경우만 예외입니다(hm-auto는 실행 대상을 단계에 명시). 다음 단계를 안내하고, 스크립트·템플릿 파일을 읽는 것은 괜찮습니다.
- hm-auto를 뺀 모든 스킬은 하네스 파일이 없을 때도 쓸 수 있습니다. 각 스킬의 "Inputs" 표를 따르고, hm-setup은 `references/no-require.md`로 REQUIRE 없이 시작합니다. config 형식은 `hm-req/templates/config.template`, REQUIRE 형식은 `hm-req/templates/REQUIRE.template.md`가 원본입니다. 하네스 없이 만든 task 파일·CR은 hm-setup이 나중에 이어받습니다 (갱신 판단은 `harness-init` 태그나 AGENTS.md 하네스 섹션으로). 하네스 없이 돌 때 `.harness/config`, AGENTS.md, `scripts/`, hook을 만들지 않습니다.
- 스킬 파일은 영어, `FLOW.md`와 대화는 한국어로 씁니다.
- 특정 도구 이름(테스트 프레임워크, 브라우저 도구, 부하 도구, 보안 스캐너 등)을 박아 넣지 않습니다. 도구는 LLM이 프로젝트마다 추천하는 구조를 유지합니다 (`FLOW.md` "테스트 도구 선택").
- `harness-state.sh`, `hm.sh`, hook 예시는 ASCII만 씁니다 (Windows에서 한글이 깨짐).
- 하네스는 make 같은 별도 빌드 도구에 의존하지 않습니다. 필요한 건 git과 bash뿐입니다.
- 스크립트는 macOS 기본 bash 3.2에서도 돌아야 합니다 (연관 배열 등 bash 4 기능 금지).
- 스크립트가 읽는 형식(`FLOW.md` "스크립트가 의존하는 규칙")을 바꾸면 `harness-state.sh`와 `hm.sh`도 함께 고칩니다. `harness-state.sh`를 고쳤으면 `bash harness-skills/hm-setup/scripts/test-harness-state.sh`가 `failed 0`으로 끝나야 합니다.

## 고친 뒤 반드시: Codex로 복사

Codex는 `~/.codex/skills/`에 있는 **복사본**을 씁니다. 여기서 고쳐도 자동으로 반영되지 않습니다.
`harness-skills/` 아래를 고쳤다면, 작업을 마치기 전에 저장소 루트에서 실행합니다 (Git Bash). 첫 줄이 공유 문단을 각 스킬로 펼칩니다 (`--check`가 실패하면 누가 복사본을 직접 고친 것이므로 원본과 맞춥니다):

```bash
bash harness-skills/sync-shared.sh && bash harness-skills/sync-shared.sh --check
for d in harness-skills/hm-*; do rm -rf ~/.codex/skills/"${d##*/}"; cp -r "$d" ~/.codex/skills/; done
for d in harness-skills/hm-*; do rm -rf ~/.claude/skills/"${d##*/}"; cp -r "$d" ~/.claude/skills/; done
diff -rq harness-skills ~/.codex/skills | grep hm- || echo "copies identical"
diff -rq harness-skills ~/.claude/skills | grep hm- || echo "copies identical"
```

- 두 `diff` 모두 `copies identical`이면 끝입니다 (Claude Code도 `~/.claude/skills/`의 복사본을 씁니다).
- 스킬 폴더를 지우거나 이름을 바꿨다면, `~/.codex/skills/`에 남은 옛 폴더도 지웁니다 (위 `diff`에 `Only in ... hm-...`로 보입니다).
