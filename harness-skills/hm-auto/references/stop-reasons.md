# Stop reasons (part of hm-auto)

Read this when a run stops: match the `reason` to a row, translate it for me in CHAT_LANG, and tell me what to do.

| Reason contains | Meaning | What to do |
|---|---|---|
| stopped to ask a question | A dev agent needs a decision | Answer it in the chat (the run continues), or later resume; the next run starts with "Continue Task <id>." |
| no task/<id> branch with commits | A start precondition failed, or a question before any change | Read the log, fix the cause, resume |
| set Task <id> to Done | The dev agent overstepped | Set the status back to In Review on its branch, resume |
| MAX_CONTINUE | The task kept running out of context | Read its Notes for Next Session; split it with hm-change or resume |
| MAX_REREVIEW | Blockers keep coming back | Read the latest review; decide, then resume (it starts with a re-review) |
| no new review file / cannot read the Verdict / reviews commit | The review step failed or reviewed the wrong commit | Read the log; resume (it reviews again) |
| review not applied yet | The apply step asked a question or failed | Answer or fix; resume (it applies the same file again) |
| not merged / merge conflict | Integration hit a conflict that needs a decision | Read the log; resolve or decide, resume |
| waiting for ... to be merged (MERGE=pr) | A pushed branch waits for the team's merge | Merge the pull request, then resume |
| waits for Task ... to be merged | Dependencies are not merged, and nothing else can run | Finish or merge those tasks first |
| uncommitted changes | A session left uncommitted work | Inspect `git status` in that worktree; commit or discard, resume |
| lock held | Another automatic run is active | If none is running, `run-end`, then resume |
