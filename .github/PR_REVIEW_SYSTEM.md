# Automated Pull Request Review System

## Overview

This repository includes an automated PR review system that acts as a code reviewer to:
1. Scan pull requests pending for review
2. Prioritize them based on labels and keywords (P0 > P1 > P2 > P3)
3. Perform automated code analysis
4. Leave review comments with findings
5. Approve documentation-only changes automatically
6. Request changes for PRs with critical issues

## Workflows

### 1. PR Reviewer Bot (`pr-reviewer-bot.yml`)

**Triggers:**
- Automatically when PR is opened, synchronized, or marked ready for review
- Manually via workflow_dispatch to review all open PRs

**Features:**
- Priority-based review (P0 critical PRs reviewed first)
- Automated code analysis for:
  - SQL migrations (DROP statements, default values, rollback comments)
  - TypeScript/JavaScript (security issues, SQL injection, hardcoded credentials)
  - YAML workflows (permissions)
- Posts detailed review comments
- Adds labels based on findings (`needs-work`, `ready-for-review`, `security-review`)
- Requests changes for PRs with critical security issues

### 2. PR Review Automation (`pr-review-automation.yml`)

**Triggers:**
- Automatically on PR events
- Manual trigger available

**Features:**
- Determines PR priority
- Analyzes changed files by type
- Reviews SQL migrations for dangerous patterns
- Performs TypeScript/JavaScript linting
- Security scanning for secrets and SQL injection
- Auto-approves documentation-only changes
- Maintains PR queue status

## Priority System

PRs are prioritized based on labels and title keywords:

| Priority | Criteria | Review Order |
|----------|----------|--------------|
| **P0** | Labels: `P0`, `critical`, `blocker`<br>Keywords in title: "p0", "critical", "blocker" | 1st (Highest) |
| **P1** | Labels: `P1`, `high-priority`, `urgent`<br>Keywords in title: "p1", "urgent" | 2nd |
| **P2** | Labels: `P2`, `medium-priority` | 3rd |
| **P3** | Default priority | 4th (Lowest) |

## How It Works

### Automatic Review Flow

```
PR Opened/Updated
    ↓
Priority Determined
    ↓
Automated Checks Run:
 - File analysis
 - Security scan
 - Code quality
 - SQL review
    ↓
Review Posted
    ↓
Labels Added
    ↓
Human Review (if needed)
```

### Manual Review Trigger

To manually review all open PRs:

1. Go to Actions tab
2. Select "PR Reviewer Bot" workflow
3. Click "Run workflow"
4. Select branch and click "Run workflow" button

The system will review the highest priority open PR.

## Review Checks

### SQL Migrations
- ✅ Checks for `DROP TABLE` without `IF EXISTS`
- ✅ Detects empty string defaults (suggests NULL instead)
- ✅ Warns about adding NOT NULL columns with defaults to existing tables
- ✅ Suggests adding rollback instructions

### TypeScript/JavaScript
- ✅ Detects hardcoded credentials
- ✅ Identifies SQL injection risks
- ✅ Flags console.log in production code
- ✅ Checks for proper parameterized queries

### Security
- ✅ Scans for potential secrets in code
- ✅ Checks for SQL injection patterns
- ✅ Validates secure coding practices

### YAML Workflows
- ✅ Checks for explicit permissions
- ✅ Validates workflow syntax

## Review Outcomes

### ✅ Approved
- No issues found
- Documentation-only changes
- Non-P0 PRs that pass all checks

### 💬 Comment
- Minor suggestions
- Non-critical issues
- P0 PRs (always require human review)

### 🚫 Request Changes
- Critical security issues
- Potential data corruption risks
- Must-fix issues before merge

## Using the System

### For PR Authors

1. **Create your PR** with a clear title and description
2. **Add priority label** if urgent (P0, P1, P2)
3. **Wait for automated review** (runs within minutes)
4. **Address any issues** found by the bot
5. **Push updates** - bot will re-review automatically
6. **Request human review** once bot approves

### For Reviewers

1. **Check automated review first** - bot finds common issues
2. **Focus on business logic** - bot handles syntax/security
3. **Review bot suggestions** - decide which to apply
4. **Approve when ready** - bot's approval doesn't replace human judgment

### Skipping Automated Review

Add `[WIP]` prefix to PR title or mark as draft to skip automated review.

## Labels

The system uses and adds these labels:

- `P0`, `P1`, `P2`, `P3` - Priority levels
- `needs-work` - Issues found, author needs to address
- `ready-for-review` - Passed automated checks
- `security-review` - Security issues detected
- `skip-review` - Skip automated review

## Configuration

### Adding Custom Checks

Edit the workflow files in `.github/workflows/`:
- `pr-reviewer-bot.yml` - Main review logic
- `pr-review-automation.yml` - Additional automation

### Adjusting Priority Rules

Modify the priority determination logic in the "Determine PR Priority" or "Get PR details" steps.

### Customizing Review Criteria

Update the "Analyze code changes" step to add new checks or modify existing ones.

## Best Practices

### For Authors
- ✅ Add meaningful PR titles with priority keywords
- ✅ Include context in PR description
- ✅ Address bot feedback promptly
- ✅ Use descriptive commit messages
- ✅ Keep PRs focused and small

### For Reviewers
- ✅ Let bot handle routine checks
- ✅ Focus on architecture and business logic
- ✅ Provide constructive feedback
- ✅ Approve promptly when ready
- ✅ Request changes clearly with actionable items

### For Maintainers
- ✅ Keep priority labels up to date
- ✅ Monitor bot effectiveness
- ✅ Update checks based on common issues
- ✅ Review bot suggestions for false positives
- ✅ Adjust automation rules as needed

## Limitations

### What the Bot CAN'T Do
- ❌ Review business logic correctness
- ❌ Assess architectural decisions
- ❌ Validate complex edge cases
- ❌ Test functionality
- ❌ Replace human code review

### What Requires Human Review
- Architecture changes
- Business logic validation
- Performance implications
- User experience considerations
- Edge case handling
- API design decisions

## Troubleshooting

### Bot Not Commenting

1. Check if PR is marked as draft
2. Verify PR has `[WIP]` in title
3. Check workflow run in Actions tab
4. Review workflow permissions

### False Positives

1. Review the specific check triggering
2. Add exception if needed
3. Update workflow configuration
4. Comment on PR explaining why safe

### Bot Approval Not Appearing

1. Bot only approves non-P0, issue-free PRs
2. Documentation-only changes auto-approved
3. Code changes require human review
4. Check for critical issues blocking approval

## Future Enhancements

- [ ] Integration with CodeQL for deeper security analysis
- [ ] Performance impact analysis
- [ ] Test coverage requirements
- [ ] Breaking change detection
- [ ] Dependency vulnerability scanning
- [ ] Automated merge for approved PRs
- [ ] Custom rule configuration per file type
- [ ] AI-powered code review suggestions

## Support

For issues with the automated review system:
1. Check the Actions tab for workflow logs
2. Review this documentation
3. Open an issue with `automation` label
4. Tag repository maintainers

---

**Remember:** Automated review is a tool to assist human reviewers, not replace them. Always use your judgment and expertise when reviewing code.
