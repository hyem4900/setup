## 플로우
0. REQUIREMENTS.md 정리
	- 요구사항을 구체화하는 중요한 단계
	- 디자인 섹션 포함: 원하는 느낌, 레퍼런스 앱 2~3개, 피하고 싶은 스타일
1. git 시작
	- git init
2. 스킬 준비
	1. mattpocock 스킬 (아래 둘 중 하나만)
		- 플러그인: `codex plugin marketplace add mattpocock/skills` → `codex plugin add mattpocock-skills@mattpocock`
		- 깃 클론: `git clone https://github.com/mattpocock/skills.git` → 스킬들을 .agents/skills로 복사 → `Remove-Item skills -Recurse -Force`
	2. 디자인 스킬
		```powershell
		New-Item -ItemType Directory -Force .agents/skills, docs
		git clone --depth 1 https://github.com/anthropics/skills.git a-skills
		git clone --depth 1 https://github.com/vercel-labs/agent-skills.git v-skills
		Copy-Item -Recurse a-skills/skills/frontend-design .agents/skills/
		Copy-Item -Recurse v-skills/skills/web-design-guidelines .agents/skills/
		Remove-Item a-skills, v-skills -Recurse -Force
		```
  		- $skill-installer anthropics의 frontend-design 설치해줘.
		- $skill-installer vercel-labs의 web-design-guidelines 도 설치해줘.
	3. 리뷰 가이드라인 로컬 저장 (샌드박스 네트워크 차단 대비)
		```powershell
		Invoke-WebRequest https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md -OutFile docs/web-interface-guidelines.md
		```
3. MCP 등록
	1. context7: `codex mcp add context7 -- npx -y @upstash/context7-mcp`
	2. playwright: `codex mcp add playwright -- npx -y @playwright/mcp@latest`
4. `$setup-matt-pocock-skills` (AGENTS.md에 작성. 트래커는 local markdown 활용)
5. AGENTS.md 규칙 추가
```
## Rules
- Workflow: $grill-with-docs → $to-spec → $frontend-design (design direction) → $to-tickets → for each ticket: $implement → $code-review (in a separate session)
- Tickets must be demoable feature units (vertical slices).
- Write tests only for core logic.
- Verify library APIs with context7.
- Use playwright only for UI verification.
- After $implement, stop without committing. Commit only after the review passes and fixes are applied.
- Respond to the user in Korean. Write code, commit messages, and comments in English.

## Design
- DESIGN.md is the single source of truth for visual direction (concept, fonts, palette, spacing, radius, shadow).
- Design tokens live in one file; never hardcode colors, font sizes, or spacing in components.
- The first UI ticket sets up the tokens and app shell with $frontend-design. Later UI tickets follow DESIGN.md and existing tokens; do not invent new styles.
- Do not change business logic or state handling during visual work.
- For UI tickets, $code-review also runs $web-design-guidelines on changed files only, using docs/web-interface-guidelines.md (do not fetch remotely). Fix all high-severity findings.
- UI verification: take playwright screenshots at mobile and desktop widths, in light and dark mode.
```
6. git 커밋
	- git add . → git commit -m "init: setup"
7. grill 시작
```
$grill-with-docs REQUIREMENTS.md의 과제를 만들려고 해. 핵심 결정 사항들을 질문해줘. 디자인 방향(느낌, 레퍼런스, 정보 밀도, 다크모드)도 포함해서.
```
8. 디자인 방향 확정 (spec 이후, tickets 이전)
```
$frontend-design spec과 REQUIREMENTS.md 기준으로 서로 다른 미적 방향 3개를 제안해줘.
각각 한 줄 컨셉, 폰트 조합, 팔레트(hex), 여백 스케일, radius/shadow 스타일로. 코드는 쓰지 마.
```
	- 하나 선택(또는 섞기) → "선택한 방향으로 DESIGN.md 작성해줘" → 커밋
