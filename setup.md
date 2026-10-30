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
## 규칙
- 흐름: $grill-with-docs → $to-spec → $to-tickets → 티켓마다 $implement → $code-review
- 티켓은 데모 가능한 기능 단위(vertical slice).
- 테스트는 핵심 로직만.
- 라이브러리 API는 context7로 확인.
- playwright는 UI 확인에만 사용.
- 티켓 완료마다 커밋.
```
6. git 커밋
	- git add . → git commit -m "init: setup"
7. grill 시작
```
$grill-with-docs REQUIREMENTS.md의 과제를 만들려고 해. 핵심 결정 사항들을 질문해줘.
```
