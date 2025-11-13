# Global Cursor Settings - All Repositories

This document describes the global Cursor IDE settings that should be configured to apply consistent AI agent behavior across all repositories.

## 📋 Overview

These settings ensure that AI agents in Cursor IDE follow consistent protocols across all your projects, regardless of repository-specific rules.

## ⚙️ Configuration Method

### Option 1: Cursor Settings UI (Recommended)

1. Open Cursor IDE
2. Click **Settings** (gear icon in top-right corner)
3. Navigate to **Cursor Settings → Rules → User Rules**
4. Add the following text in the User Rules field:

```
FILE CREATION PROTOCOL - APPLY TO ALL PROJECTS:

NEVER create new files like summary.md, steps.md, plan.md, notes.md, analysis.md, 
report.md, review.md, or any documentation files automatically in response to chat 
questions unless the user explicitly requests file creation with phrases like:
- "create a file"
- "write to file"
- "save as"
- "export to file"
- "generate documentation file"

Always respond with explanations, code, or analysis INLINE in the chat.

PLANNING PROTOCOL:
- Present plans inline in chat, NOT as separate files
- Use "first plan, then execute" approach
- Wait for user confirmation before executing complex plans
- Only create plan files if explicitly requested

CODE REVIEW PROTOCOL:
- Use chunked review approach for large codebases
- Present review findings inline in chat
- Break reviews into logical chunks (by file, by feature, by module)
- Review one chunk at a time, wait for feedback before next chunk
- Only create review files if explicitly requested

WORKFLOW PRINCIPLES:
- Execute directly when task is clear and straightforward
- Ask for clarification only when genuinely uncertain
- Avoid unnecessary intermediate steps
- Focus on delivering working solutions

FILE CREATION RULES:
Only create files when:
1. User explicitly says "create file" or similar command
2. Implementing source code as part of development tasks
3. User confirms file creation when asked

When uncertain, ask: "Would you like me to save this as a file?"

FORBIDDEN FILE TYPES (without explicit request):
- summary.md, SUMMARY.txt, overview.*
- steps.md, plan.md, roadmap.md, TODO.md
- notes.md, documentation.md, guide.md
- analysis.md, report.md, findings.md
- review.md, code-review.md
- Any .txt or .md file not explicitly requested

ALLOWED without explicit request:
- Source code files (.py, .js, .ts, .cpp, .sh, etc.) when implementing features
- Configuration files when setting up tools/frameworks
- Test files when asked to write tests
```

### Option 2: Settings JSON (Optional)

Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) → **Preferences: Open Settings (JSON)**, and add:

```json
{
  "cursor.chat.autoSave": false,
  "files.autoSave": "off"
}
```

**Note**: The `cursor.chat.preventAutoFileCreation` option may not exist yet, but this documents your intention if Cursor adds this feature in the future.

## 🔄 Hierarchy of Rules

The rule hierarchy works as follows:

1. **Global User Rules** (Cursor Settings → Rules → User Rules)
   - Apply across all projects
   - Provide baseline protocol
   - Broad, general guidelines

2. **Repository `.mdc` Rules** (`.cursor/rules/*.mdc` files)
   - Override/augment global rules for specific repos
   - More detailed, repository-specific enforcement
   - Can be more restrictive than global rules

3. **Rule Priority**:
   - Repository rules take precedence over global rules
   - More specific rules override general rules
   - Both are loaded and applied together

## 📁 Multi-Repository Setup

### For New Repositories

When creating a new repository, you can:

1. **Copy the template**: Copy `.cursor/rules/MASTER-RULES-INDEX.mdc` and all `MASTER-RULES-*.mdc` modules from this repository to new repositories
2. **Customize as needed**: Modify repository-specific rules while keeping global protocol
3. **Document in README**: Add a section about AI agent protocols (see README.md in this repo)

### For Existing Repositories

1. Create `.cursor/rules/` directory in repository root
2. Copy or create appropriate `.mdc` rule files
3. Commit to version control so all team members inherit the protocol
4. Update repository README with AI agent protocol information

## ✅ Verification

### Check Active Rules

1. In Cursor Settings → Rules, you can view active rules
2. The UI shows which rules are applied to current context
3. Rules with `alwaysApply: true` are always loaded

### Test the Rules

1. Ask the AI: "Summarize this codebase"
   - ✅ Should respond inline in chat
   - ❌ Should NOT create summary.md file

2. Ask the AI: "Review this code"
   - ✅ Should provide review inline, chunked if large
   - ❌ Should NOT create review.md file

3. Ask the AI: "Create a summary.md file with codebase overview"
   - ✅ Should create the file as requested (explicit request)

## 📝 Team Documentation

### Add to Organization Guidelines

Consider adding to your organization's development guidelines:

```markdown
## AI Assistant Protocol

All repositories enforce strict file creation rules. The AI will NOT automatically 
create summary/plan/documentation files. All responses are provided inline unless 
you explicitly request file creation.

### Requesting Files

To get the AI to create a file, use explicit phrases:
- "create a file named X"
- "write this to a file"
- "save as filename.ext"
- "export to file"

### Planning

Plans are presented inline in chat. If you want a plan file, explicitly request it:
- "save this plan to a file"
- "create a plan.md file with this"
```

## 📝 Creating or Updating Repository Rules

### Creating New Rule Files

1. **Create `.mdc` file** in `.cursor/rules/` directory:
   - Use numbered prefix: `000-MANDATORY-READ-FIRST.mdc` (if pre-work checklist), `001-rule-name.mdc`, `002-rule-name.mdc`, etc.
   - Rules are processed in alphabetical order (000 is processed first)
   - Use `000-` prefix for mandatory pre-work verification files

2. **Add YAML frontmatter**:
   ```yaml
   ---
   name: Rule Name
   description: Rule description - SOURCE OF TRUTH for enforcement
   version: "1.0"
   alwaysApply: true
   globs:
     - "**/*"
   ---
   ```

3. **Add rule content** in markdown format:
   - Start with "🚨 MANDATORY - READ FIRST" header for critical rules
   - Include "⚠️ CRITICAL ENFORCEMENT NOTICE" section
   - Add "🔴 BEFORE STARTING ANY WORK - MANDATORY VERIFICATION" checklist
   - Use strong language: "YOU MUST", "STRICTLY ENFORCED", "ABSOLUTELY MANDATORY"

4. **Rules are automatically enforced** by Cursor IDE

### Updating Existing Rules

1. **Edit the master rules file**:
   - All rules → `.cursor/rules/MASTER-RULES-INDEX.mdc` (MASTER INDEX & SINGLE SOURCE OF TRUTH) + focused modules

2. **Rules are automatically reloaded** by Cursor IDE
3. **Changes apply immediately** to all AI agents
4. **Update version number** in YAML frontmatter if making significant changes

### Rule Maintenance Guidelines

**When Adding New Rules**:
1. Add to appropriate `.mdc` file
2. Update version number if major change
3. Test that rules are enforced
4. Verify rules work as expected

**When Removing Rules**:
1. Remove from `.mdc` file
2. Update version number if major change
3. Verify rules are no longer enforced

**When Modifying Rules**:
1. Edit `.mdc` file directly
2. Update version number if significant change
3. Test changes work as expected

## 🔧 Troubleshooting

### Rules Not Applying

1. **Check rule file location**: Must be in `.cursor/rules/*.mdc`
2. **Check YAML frontmatter**: Must have valid YAML with `alwaysApply: true`
3. **Check file extension**: Must be `.mdc` (Markdown Cursor)
4. **Reload Cursor**: Sometimes rules need a reload to take effect
5. **Check global settings**: Verify User Rules in Cursor Settings

### Conflicting Rules

1. **Repository rules override global rules**: More specific rules take precedence
2. **Check rule order**: Rules are processed in alphabetical order (use numbered prefixes)
3. **Review both rule sets**: Ensure they're not contradictory

### Verification Steps

**Check if rules are active**:
1. Open Cursor IDE in repository
2. Go to Settings → Rules
3. You should see rules listed as "Repository Rules"
4. Rules with `alwaysApply: true` are always active

**Test enforcement**:
1. Ask AI: "Summarize this codebase"
   - ✅ Should respond inline (no file created)
   - ❌ Should NOT create summary.md

2. Ask AI: "Create a new branch"
   - ✅ Should refuse and explain beta branch rule
   - ❌ Should NOT create new branch

3. Ask AI: "Commit these changes"
   - ✅ Should verify branch and files first
   - ✅ Should ask for explicit approval
   - ❌ Should NOT commit without approval

## 📚 Additional Resources

- [Cursor Rules Documentation](https://cursor.com/docs/context/rules)
- [Cursor Best Practices](https://github.com/digitalchild/cursor-best-practices)
- Repository-specific rules: See `.cursor/rules/` directory in each repository

## 🎯 Rule Hierarchy

1. **Repository Rules** (`.cursor/rules/*.mdc`) - Highest priority
   - Apply to this repository only
   - Override global rules
   - Always active (`alwaysApply: true`)
   - Source of truth for repository-specific rules

2. **Global Rules** (Cursor Settings → User Rules) - Baseline
   - Apply to all repositories
   - Provide baseline protocol
   - Can be overridden by repository rules

3. **User Instructions** (chat context) - Temporary
   - Apply to current conversation
   - Can override rules if explicitly stated
   - Temporary (not persistent)

## 🚨 Important Notes

- **`.mdc` files are the ONLY source of truth** for repository rules
- **Repository rules override global rules** when they conflict
- **Cursor IDE automatically enforces `.mdc` files** - no manual configuration needed
- **All rule changes must be made in `.mdc` files** - editing other files won't change enforcement
- **Do NOT duplicate rules** in multiple files - keep single source of truth

## 🎯 Summary

**Key Principles**:
- ✅ Respond inline in chat
- ✅ Files only when explicitly requested
- ✅ First plan, then execute
- ✅ Chunked code reviews
- ✅ Execute directly when clear

**Forbidden**:
- ❌ Automatic file creation for summaries/plans/documentation
- ❌ Creating plan files without request
- ❌ Creating review files without request
- ❌ Unnecessary intermediate files

---

**Last Updated**: 2025-01-27
**Version**: 1.0

