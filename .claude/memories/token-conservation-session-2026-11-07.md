---
name: token-conservation-session-2026-11-07
description: REA provider verification task - session start quota check
metadata:
  type: project
---

**Session Start:** 2026-11-07  
**Task:** REA Android provider verify against official docs + headless JADX integration  
**Read Budget Set:** 8 reads (bug fix scope - max 5 reads allowed for targeted verification)  
**Token Conservation Tactics Applied:**
- Token-conservation skill mandatory run at session start
- Discovery read budget fixed BEFORE any file reads
- Single-focus task: REA provider JAR, Java reqs, MCP env, startup checks
- No broad scans - only targeted reads of relevant files

**Context Plan (8-read max):**
1. REA MCP server config (.claude/mcp_servers/rea.mcp.json)
2. Existing rea_report.md (if present)
3. JDK version in system
4. Provider JAR location/version
5. Any existing SKILL.md for REA-related skills

**Compression Review:**
- Single-task focus: REA verification only
- Will not read unrelated files or broad codebase scans
- Output will show PASS/FAIL/NOT TESTED per each check

**Logging:**
- Session started with token-conservation workflow
- Remaining budget: standard session quota
- Recommendation: No /new or /compact needed yet (single task)
