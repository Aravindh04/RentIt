---
name: apex-test-runner
description: Runs Apex tests and reports only failures and coverage gaps. Use after Apex/Flow changes.
tools: Bash, Read
model: sonnet
---

Run: sf apex run test --target-org <alias> --code-coverage --result-format human --wait 10
Report only failed tests (with exact error) and classes below 75% coverage.