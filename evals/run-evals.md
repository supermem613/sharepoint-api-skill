# SharePoint API Skill — Eval Runner

You are evaluating the **sharepoint-api-skill**. This instruction tells you how to run all evals and produce a scored report.

## Prerequisites

1. **Install dependencies** (one-time):
   ```bash
   npm install
   ```

2. **Authenticate** to the target SharePoint **site** (not just the tenant — a specific site URL):
   ```bash
   source .claude/skills/sharepoint-api/scripts/sp-auth-wrapper.sh <tenant>.sharepoint.com
   ```
   Then set `SP_SITE` to the specific site you want to test against:
   ```bash
   export SP_SITE="https://<tenant>.sharepoint.com/sites/<sitename>"
   ```
   For example:
   ```bash
   source .claude/skills/sharepoint-api/scripts/sp-auth-wrapper.sh contoso.sharepoint.com
   export SP_SITE="https://contoso.sharepoint.com/sites/eval-test"
   ```

3. **Verify** auth works against the target site:
   ```bash
   node .claude/skills/sharepoint-api/scripts/sp-get.js "/_api/web?\$select=Title,Url"
   ```

   This must return the **specific site's** title and URL (not the tenant root). If it returns the wrong site, fix `SP_SITE`.

   > ⚠️ **Warning:** Evals 06-08 create/update/delete list items, and evals 12-13 upload/delete files. All test data uses the `EVAL_TEST_` prefix and is cleaned up. **Only run against a test or development site, not production.**

## How to Run

1. Read each prompt file in `evals/prompts/` in order (01 through 20)
2. For each eval:
   a. Read the **Task** section and execute it
   b. After completing (or failing), check yourself against the **Checks** section
   c. Score yourself: ✅ PASS | ⚠️ PARTIAL | ❌ FAIL
   d. Record the result
3. After all evals, write the report to `evals/results/report.md`

## Scoring Rules

- **✅ PASS** — All checks satisfied. The operation completed successfully using the correct approach.
- **⚠️ PARTIAL** — The operation succeeded but not all checks passed (e.g., used a different but valid endpoint, or got partial results).
- **❌ FAIL** — The operation failed, used an invalid endpoint, or couldn't complete the task.

## Report Format

Write the report as:

```markdown
# Eval Report — [date]

**Site:** [site URL]
**Overall:** [passed]/[total] ([percentage]%)

## Summary by Category

| Category | Passed | Total | Score |
|----------|--------|-------|-------|
| Auth | X | 1 | X% |
| Discovery | X | 3 | X% |
| List CRUD | X | 5 | X% |
| Files | X | 4 | X% |
| Search | X | 2 | X% |
| Users | X | 2 | X% |
| Advanced | X | 3 | X% |

## Detailed Results

| # | Eval | Score | Notes |
|---|------|-------|-------|
| 01 | Authenticate | ✅ | ... |
| 02 | Discover lists | ✅ | Found 9 lists |
| ... | ... | ... | ... |

## Failures & Issues

[For any ❌ or ⚠️, explain what went wrong and what the expected behavior was]
```

## Important Notes

- **Clean up after yourself.** Any test items/files you create must be deleted at the end.
- **Use the skill's scripts.** The whole point is evaluating whether the skill enables you to do these tasks. Use `sp-get.js`, `sp-post.js`, `graph-get.js`, `graph-post.js` as documented in SKILL.md.
- **Don't skip evals.** If an eval fails, record it and move on. The failure IS the data.
- **Be honest in self-scoring.** If you hallucinated an endpoint or got an error, that's ❌ not ⚠️.
