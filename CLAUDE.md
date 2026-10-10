# CLAUDE.md — Rescu (Yindii Flutter assessment)

This file is read automatically by Claude Code at the start of every session.
It holds the permanent rules. Task instructions come from my prompts.

## Who I am and what I need
- I am an entry-level developer doing a take-home assessment for a Junior Flutter role.
- In the follow-up interview they will pick lines from my diff and ask me to explain them.
- So: I must understand every line. Teach me as you go. Explain in simple English.
- I prefer brief, direct answers in plain-English bullet points.
- Show me the plan and the key code changes before applying large edits.

## Project facts
- Flutter app "Rescu" (surplus-food marketplace). NOT a web/React app.
- Stack: Flutter 3.27.0 (pinned in `.fvmrc`), Dart, Java 17 for Android, GetX (state, DI, routing),
  hand-written JSON models, `flutter_map`, `pull_to_refresh`, `cached_network_image`, `visibility_detector`.
- Layout: `lib/model`, `lib/service` (app-wide GetX services), `lib/repository`, `lib/routes`,
  `lib/binding` (per-route bindings), `lib/middleware`, `lib/feature/<name>/` (screen + controller + widgets),
  `lib/feature/shared_widget/`.
- Simulated backend: `lib/service/fake_api_service.dart` + seed data in `assets/data/`.
- Full brief: `PROBLEM.md`. Setup: `README.md`.

## HARD RULES (never break)
1. NEVER modify `lib/service/fake_api_service.dart` or anything in `assets/data/`. Read them only, to learn the API contract.
2. NEVER upgrade Flutter or any package. Never run `flutter pub upgrade`. Do not change `pubspec.yaml` versions or `pubspec.lock`.
3. Use `fvm flutter ...` if FVM is installed, otherwise `flutter ...`. Check `flutter --version` shows 3.27.0.
   - Exception (from PROBLEM.md): 3.38.10 is allowed ONLY for debugging on a physical iOS 26 iPhone.
     If used, do NOT commit files it regenerates (`pubspec.lock`, iOS project files).
4. No symptom-hiding fixes: no broad try/catch, no swallowing errors, no forced rebuilds, no `if (mounted)`
   band-aids without fixing ownership. The brief says a hidden symptom scores WORSE than a correct diagnosis with no fix.
5. No new packages. No big rewrites. Follow existing GetX patterns, naming, and folder structure.
6. Never fabricate anything: test results, DevTools numbers, screenshots, commits, time spent, AI mistakes.
   If you could not run a command, say so plainly.
7. Never weaken or delete a legitimate test to make the suite pass.
8. NEVER run `git add`, `git commit`, or `git push`. Propose the commit message and the exact list of files;
   I run git add/commit myself. Also never force-push, rewrite history, or send anything external
   without my explicit approval.

## How to work on a bug ticket (RES-xxx)
1. Read all relevant code and trace the real data flow. Do not guess the cause from the ticket text.
2. Explain the root cause to me, with file + line references, and a concrete repro scenario.
3. Wait for my OK before editing.
4. Write a test that FAILS on the current code (when practical), then fix, then show it PASSES.
5. Smallest robust fix. Prefer deterministic tests (Completer, fakeAsync, injected clock) over real delays.
6. Run: `dart format` on changed files, focused test, full `flutter test`, `flutter analyze`.
7. Show me `git diff --stat` and the important hunks. Confirm forbidden files are untouched.
8. Teach-back, then propose the commit (I run git myself).

## Commits
- Propose the commit message and the exact list of files; I run git add/commit myself.
  Never run `git add`, `git commit`, or `git push`.
- One logical change per commit. Ticket prefix required.
- Message must say WHAT and WHY, e.g.
  `[RES-101] Ignore stale search responses because out-of-order futures overwrote newer results`
- Never "wip", "fix", "update". Never mix two tickets in one commit.
- Before each commit: `git status`, check the diff only contains this ticket.
- It's fine (and honest) to keep the Co-Authored-By trailer — AI use is allowed in this assessment.

## Testing
- Use `flutter_test`. Existing tests: `test/model_test.dart`.
- Put new tests under `test/` mirroring `lib/` (e.g. `test/feature/search/search_deals_controller_test.dart`).
- If you need a test seam (e.g. inject a clock or API), keep it minimal and explain why.
- Separate pre-existing failures from new ones.

## Performance (RES-105, F-1)
- You probably cannot run DevTools in this environment. I have no physical Android device: I will measure on an
  Android emulator in DEBUG mode (rebuild counts + memory/image-cache trend). Frame times from debug mode are not
  representative — never present them as real performance.
- BEFORE any RES-105 code change: remind me to capture "before" DevTools evidence
  (frame chart, rebuild counts, memory, image cache) and give me exact steps.
- Never write performance numbers I did not give you.

## Living files (keep these updated)
- `PROGRESS.md` — after every ticket/feature: status, commit hash, open questions, next step.
  (So a new session can continue without losing context.)
- `AI_LOG.md` — whenever a suggestion from you (or another AI) turns out wrong or misleading,
  remind me to log it: what was suggested, how we caught it, what we did instead.
  The brief requires at least 2 REAL examples. Never invent them.
- `solutions.md` — final write-up at repo root (built from PROGRESS.md + AI_LOG.md at the end).

## Teach-back after every ticket/feature
Explain in simple English:
- What was wrong, why it happened, which code caused it.
- What changed and why the fix works.
- An edge case that could still break it, and edge cases we chose NOT to handle (and why).
- How the tests prove it.
- 3–5 likely interview questions with short answers based on the actual code.
Then ask me to explain the fix back in my own words and correct me if I'm wrong.

## End of each phase, report
- Work done, files changed, commands actually run + results, failures, decisions I need to make, next step.
