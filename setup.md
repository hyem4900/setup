## 플로우
0. REQUIREMENTS.md 정리
	- 요구사항을 구체화하는 중요한 단계
1. git 시작
	- git init
2. 스킬 준비
	- `codex plugin marketplace add mattpocock/skills`
		- `codex plugin add mattpocock-skills@mattpocock`
	- 깃 클론 : `git clone https://github.com/mattpocock/skills.git`
		1. 스킬들 복사해서 .agents/skills로 복사
		2. 클론 레포 삭제 : `rm skills -Force`
3. MCP 등록
	1. context7: `codex mcp add context7 -- npx -y @upstash/context7-mcp`
	2. playwright: `codex mcp add playwright -- npx -y @playwright/mcp@latest`
4. `$setup-matt-pocock-skills` (AGENTS.md에 작성. 트래커는 local markdown 활용)
5. AGENTS.md 규칙 추가
```
## Rules
- Workflow: $grill-with-docs → $to-spec → $to-tickets → for each ticket: $implement → $code-review (in a separate session)
- Never move to the next workflow step or ticket on your own. When a step is done, report the result and wait for the user's instruction.
- Tickets must be demoable feature units (vertical slices).
- Write tests only for core logic.
- Verify library APIs with context7.
- Use playwright only for UI verification.
- After $implement, stop without committing. Commit only after the review passes and fixes are applied.
- Respond to the user in Korean. Write code, commit messages, and comments in English.
```
6. git 커밋
	- git add . → git commit -m "init: setup"
7. grill 시작
```
$grill-with-docs REQUIREMENTS.md의 과제를 만들려고 해. 핵심 결정 사항들을 질문해줘.
```
