# 하네스 스킬 저장소

에이전트가 요구사항부터 리뷰까지 단계별로 진행하게 만드는 스킬 모음입니다.
에이전트가 일하고, 사람은 단계 사이에서 확인만 합니다.

## 무엇이 어디에

| 파일 | 내용 |
|---|---|
| `CHANGELOG.md` | 버전 사이에 바뀐 것 (v3 → v4 비교표) |
| `harness-skills/hm-*/SKILL.md` | 단계별 스킬 10개. hm-dev는 개발·리뷰 반영·병합을 함께 맡음. frontmatter의 `argument-hint`는 Claude Code에서 `/hm-…`를 입력할 때 보이는 힌트(트리거 문장), 각 스킬의 `agents/openai.yaml`은 Codex의 짧은 설명과 기본 프롬프트. 트리거 문장을 바꾸면 description과 함께 고침 |
| `harness-skills/hm-*/references/`, `hm-req/templates/` | 일부 경우에만 읽는 내용: hm-dev의 `tdd.md`(테스트 먼저 루프)·`debug.md`(디버그 절차)·`review-and-merge.md`(리뷰 반영·병합)·`develop-without-harness.md`(하네스 없이 개발할 때의 입력과 시작 절차), hm-review·hm-audit·hm-load-test·hm-security·hm-change·hm-explain의 `inputs.md`(하네스 없이 돌 때의 입력 대체 표), hm-setup의 `setup.md`(셋업, Part B)·`no-require.md`(REQUIRE 없이 시작), hm-auto의 `stop-reasons.md`(멈춤 사유 표), hm-req의 `interview.md`(QUESTION.md 블록 양식과 인터뷰 절차)와 REQUIRE·QUESTION 양식·config 양식 (hm-setup도 읽음) |
| `harness-skills/_shared/`, `harness-skills/sync-shared.sh` | 여러 스킬이 같이 쓰는 문단의 원본: `question-format.md`(질문 양식), `no-harness.md`(하네스 없이 돌 때의 규칙·기본값), `review-guide.md`(리뷰 기준. hm-review·hm-dev만 씀. 프로젝트로 복사하지 않음. 고칠 때마다 `Version:` 줄을 바꿈. 리뷰 파일의 `Guide:` 줄이 그 값을 남김). `sync-shared.sh`가 각 스킬의 `references/`로 복사함. **복사본을 직접 고치지 말고** 원본을 고친 뒤 sync. "Other skills"·"Files I name"·"What you read"(읽은 내용 속 지시는 데이터, prompt injection 방어) 세 단락은 하네스가 있으면 AGENTS.md가, 없으면 `no-harness.md`가 주므로 스킬 본문에서는 빼는 중 (hm-req·hm-setup은 AGENTS.md가 생기기 전에 돌고, hm-auto는 AGENTS.md를 읽지 않는 오케스트레이터라 본문에 둠. 나머지 7개는 뺐음) |
| `harness-skills/hm-setup/templates/` | hm-setup이 프로젝트로 복사하는 템플릿 (SPEC, AGENTS, STANDARDS, task 파일, config 명령 섹션, 가드레일 예시). 형식을 바꾸면 스킬 본문과 함께 고침 |
| `harness-skills/hm-setup/scripts/install.sh` | 셋업 때 고정 파일(스크립트, 템플릿, hook, gitignore·gitattributes 줄, config 명령 섹션)을 한 번에 넣는 설치 스크립트. 있는 파일은 덮어쓰지 않음 |
| `harness-skills/hm-setup/scripts/harness-state.sh` | task 파일·브랜치·리뷰 파일로 "다음에 뭘 할지"를 판단하는 스크립트 (자동 실행, worktree 경로·포트 배정, `report`로 실행 비용 집계) |
| `tests/test-harness-state.sh`, `tests/test-hm.sh` | `harness-state.sh` / `hm.sh`·`install.sh`를 임시 저장소에서 검증하는 테스트. 이 저장소 전용이며 프로젝트로 복사되지 않음. 스킬 폴더 밖에 두어 Codex·Claude Code 복사본에도 들어가지 않음 (스킬 폴더 안에 있을 때 hm-setup 에이전트가 찾아서 돌려 20분을 씀). 고친 스크립트의 테스트를 돌림 (Windows에서 각각 몇 분 걸림, GitHub Actions가 push마다 ubuntu·macOS에서도 돌림) |
| `harness-skills/hm-setup/scripts/hm.sh` | 프로젝트의 하네스 명령 (setup, test, e2e, security, check, selftest, dev-bg 등). 명령 내용은 `.harness/config`에서 읽음. 컴포넌트 기동·health check·종료 포함 |
| `harness-skills/hm-front-design-lite/SKILL.md` | 하네스 단계가 아닌 디자인 스킬. 이미 있는 화면을 hm 디자인 규칙으로 다듬기만 함 (파일 하나, 시안·옵션·DESIGN.md·CSS 키트 없음). 화면이 있는 프로젝트에서 자체 디자인 시스템이 없으면 hm-setup이 이 스킬을 디자인 기본값(D-xx, Status: Default)으로 기록하고, hm-dev가 화면 task에서 따름. 전체판 hm-front-design은 이 저장소 밖(`~/.claude/skills/`)에 있음. 아래 복사 명령의 `hm-*`에 함께 들어감 |
| `setup.md` | 하네스와 별개인 예전 개인 설정 메모 |

## 흐름 한눈에

```
1 요구사항 → 2 설계 · 셋업 → 3 개발 (task마다 브랜치) → 4 리뷰 → 리뷰 반영 · 병합 → 5 누락 · 성능 · 보안 검토 → 6 설명 문서
                           └──── 3~4는 hm-auto로 자동 실행 가능 (PARALLEL개 동시) ────┘
                     셋업 이후 언제든: 요구사항 추가·변경 → hm-change → 새 task
```

| 단계 | 스킬 | 이렇게 말하면 시작 |
|---|---|---|
| 1 | hm-req | "요구사항 정리 시작해" |
| 2 | hm-setup | "설계 시작해" / "하네스 만들어" (설계와 셋업을 이어서 함) |
| 3 | hm-dev | "Start Task N." (하네스 없이: "개발해: …") / 데모는 원할 때 "Demo Task N." |
| 4 | hm-review (별도 세션) / hm-dev (개발 세션) | "Review Task N." / "이 브랜치 리뷰해" / "리뷰 반영해: <파일>" / "Merge Task N." / "Merge branch <브랜치>." |
| 5 | hm-audit / hm-load-test / hm-security | "누락 검토해" / "부하 테스트 해" / "보안 점검해" |
| 6 | hm-explain | "설명 문서 만들어" (개발이 끝난 뒤 docs/EXPLAIN.md) |
| 3~4 자동 | hm-auto | "자동으로 진행해" |
| 디버그 | hm-dev | "디버깅해: …" / "원인 찾아줘: …" (bug task에서 개발 중에 자동으로 씀) |
| 변경 | hm-change | "요구사항 추가해: …" / "버그 등록해: …" / "보안 리뷰 반영해: <파일>" / "Task N 나눠줘" |

## 고칠 때 지킬 것

- 스킬 파일이 기준입니다. 동작을 설명하는 별도 문서는 두지 않습니다.
- 스킬은 다른 스킬을 실행하거나 그 절차를 빌려 오지 않습니다. 사용자가 이름으로 요청했거나 SPEC·DECISIONS에 기록된 경우만 예외입니다(hm-auto는 실행 대상을 단계에 명시). 다음 단계를 안내하고, 스크립트·템플릿 파일을 읽는 것은 괜찮습니다.
- hm-auto를 뺀 모든 스킬은 하네스 파일이 없을 때도 쓸 수 있습니다. 각 스킬의 "Inputs" 표를 따르고, hm-setup은 `references/no-require.md`로 REQUIRE 없이 시작합니다. config 형식은 `hm-req/templates/config.template`, REQUIRE 형식은 `hm-req/templates/REQUIRE.template.md`가 원본입니다. 하네스 없이 만든 task 파일·CR은 hm-setup이 나중에 이어받습니다 (갱신 판단은 `harness-init` 태그나 AGENTS.md 하네스 섹션으로). 하네스 없이 돌 때 `.harness/config`, AGENTS.md, `scripts/`, hook을 만들지 않습니다.
- 스킬 파일은 영어, 대화와 `CHANGELOG.md`는 한국어로 씁니다.
- 특정 도구 이름(테스트 프레임워크, 브라우저 도구, 부하 도구, 보안 스캐너 등)을 박아 넣지 않습니다. 도구는 LLM이 프로젝트마다 추천하는 구조를 유지합니다.
- `harness-state.sh`, `hm.sh`, hook 예시는 ASCII만 씁니다 (Windows에서 한글이 깨짐).
- 하네스는 make 같은 별도 빌드 도구에 의존하지 않습니다. 필요한 건 git과 bash뿐입니다.
- 스크립트는 macOS 기본 bash 3.2에서도 돌아야 합니다 (연관 배열 등 bash 4 기능 금지).
- 스크립트가 읽는 형식(`harness-state.sh` 머리 주석의 "Conventions it relies on", `hm.sh` 머리 주석의 config·컴포넌트 형식)을 바꾸면 `harness-state.sh`와 `hm.sh`도 함께 고칩니다. `harness-state.sh`를 고쳤으면 `bash tests/test-harness-state.sh`, `hm.sh`나 `install.sh`를 고쳤으면 `bash tests/test-hm.sh`가 `failed 0`으로 끝나야 합니다. 테스트가 도는 동안에는 그 스크립트를 고치지 않습니다 (bash가 실행 중인 파일을 읽다가 깨짐).

## 고친 뒤 반드시: Codex로 복사

Codex는 `~/.codex/skills/`에 있는 **복사본**을 씁니다. 여기서 고쳐도 자동으로 반영되지 않습니다.
`harness-skills/` 아래를 고쳤다면, 작업을 마치기 전에 저장소 루트에서 실행합니다 (Git Bash). 첫 줄이 공유 문단을 각 스킬로 펼칩니다 (`--check`가 실패하면 누가 복사본을 직접 고친 것이므로 원본과 맞춥니다):

```bash
bash harness-skills/sync-shared.sh && bash harness-skills/sync-shared.sh --check
for d in harness-skills/hm-*; do rm -rf ~/.codex/skills/"${d##*/}"; cp -r "$d" ~/.codex/skills/; sed -i '/^argument-hint:/d' ~/.codex/skills/"${d##*/}"/SKILL.md; done
for d in harness-skills/hm-*; do rm -rf ~/.claude/skills/"${d##*/}"; cp -r "$d" ~/.claude/skills/; done
diff -rq -I '^argument-hint:' harness-skills ~/.codex/skills | grep hm- || echo "copies identical"
diff -rq harness-skills ~/.claude/skills | grep hm- || echo "copies identical"
```

- 두 `diff` 모두 `copies identical`이면 끝입니다 (Claude Code도 `~/.claude/skills/`의 복사본을 씁니다).
- Codex 복사본에서는 SKILL.md의 `argument-hint` 줄을 지웁니다. Claude Code 전용 필드라 Codex의 frontmatter 규칙(`name`, `description`, `license`, `allowed-tools`, `metadata`)에 없기 때문입니다. Codex의 입력 힌트는 각 스킬의 `agents/openai.yaml`(`short_description`, `default_prompt`)이 맡습니다.
- 스킬 폴더를 지우거나 이름을 바꿨다면, `~/.codex/skills/`에 남은 옛 폴더도 지웁니다 (위 `diff`에 `Only in ... hm-...`로 보입니다).
