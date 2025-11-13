# Spec Kit Workflow Guide

## How to Use and Modify the Spec Kit

### Overview
The spec kit contains 7 main categories that track the complete development lifecycle:
1. **constitution.md** - Core principles and rules
2. **specify.md** - Current specifications and requirements
3. **clarify.md** - Issues resolved and clarifications
4. **plan.md** - Development plan and roadmap
5. **tasks.md** - Current and future tasks
6. **analyze.md** - Analysis and conflict resolution
7. **implement.md** - Implementation status and details

### Workflow Process

#### 1. When Starting New Work
1. **Read constitution.md** - Understand core principles
2. **Check specify.md** - Review current specifications
3. **Review clarify.md** - Understand resolved issues
4. **Check plan.md** - See current development plan
5. **Review tasks.md** - See what needs to be done
6. **Check analyze.md** - Understand potential conflicts
7. **Review implement.md** - See what's already implemented

#### 2. When Making Changes
1. **Update specify.md** - Add new specifications
2. **Update clarify.md** - Document any issues resolved
3. **Update plan.md** - Add new plans or update existing
4. **Update tasks.md** - Add new tasks or update status
5. **Update analyze.md** - Add new analysis or conflicts
6. **Update implement.md** - Document implementation details

#### 3. When Completing Work
1. **Update tasks.md** - Mark tasks as completed
2. **Update implement.md** - Document what was implemented
3. **Update clarify.md** - Document any issues resolved
4. **Update specify.md** - Update specifications if changed
5. **Update plan.md** - Update roadmap if needed

### Modification Guidelines

#### Adding New Entries
- **Be Specific**: Clear, detailed descriptions
- **Be Complete**: Include all relevant information
- **Be Accurate**: Up-to-date and correct
- **Be Consistent**: Follow established format

#### Updating Existing Entries
- **Mark Changes**: Use ✅ for completed, [ ] for pending
- **Update Status**: Keep status current
- **Add Details**: Include implementation details
- **Document Issues**: Record any problems

#### Conflict Resolution
- **Identify Conflicts**: Document in analyze.md
- **Plan Resolution**: Add to plan.md
- **Implement Fix**: Document in implement.md
- **Verify Resolution**: Update clarify.md

### File-Specific Guidelines

#### constitution.md
- **Core Principles**: Fundamental rules that don't change
- **Branch Rules**: Workflow requirements (enforced by `.cursor/rules/MASTER-RULES-WORKFLOW.mdc` Part 2)
- **File Management**: What can and cannot be modified
- **Quality Standards**: Expected code and documentation quality
- **Rules System**: References to centralized rules (`.cursor/rules/*.mdc`)

#### specify.md
- **Current Specs**: What the system currently does
- **Requirements**: What needs to be implemented
- **Components**: All software and hardware components
- **Status**: What's working and what's not

#### clarify.md
- **Issues Resolved**: Problems that have been fixed
- **Root Causes**: Why problems occurred
- **Solutions**: How problems were resolved
- **Current Status**: What's clear and what's not

#### plan.md
- **Completed Tasks**: What has been done
- **Current Status**: Where we are now
- **Future Plans**: What's planned next
- **Success Criteria**: How we measure success

#### tasks.md
- **Task List**: All current and future tasks
- **Status**: Completed, pending, in progress
- **Categories**: Critical, important, nice to have
- **Dependencies**: What tasks depend on what

#### analyze.md
- **Strengths**: What's working well
- **Weaknesses**: What needs improvement
- **Opportunities**: What could be added
- **Threats**: What could go wrong
- **Risks**: High, medium, low risk items

#### implement.md
- **Implementation Status**: What's been implemented
- **Details**: How things were implemented
- **Quality**: Code and documentation quality
- **Metrics**: Success criteria and performance

### Best Practices

#### Documentation
- **Keep Updated**: Update files as work progresses
- **Be Consistent**: Use consistent formatting and terminology
- **Be Complete**: Include all relevant information
- **Be Clear**: Write for others to understand

#### Workflow
- **Follow Process**: Use the established workflow
- **Update Status**: Keep status current
- **Document Changes**: Record what was changed and why
- **Verify Work**: Check that changes are correct

#### Quality
- **Review Changes**: Check work before committing
- **Test Implementations**: Verify functionality works
- **Document Issues**: Record any problems encountered
- **Learn from Mistakes**: Update process to prevent repeats

### Common Scenarios

#### Adding New Software
1. Update specify.md with new requirements
2. Update plan.md with implementation plan
3. Add tasks to tasks.md
4. Update analyze.md with potential conflicts
5. Implement the changes
6. Update implement.md with details
7. Update clarify.md if issues were resolved

#### Fixing Bugs
1. Update clarify.md with problem description
2. Update analyze.md with root cause analysis
3. Add fix tasks to tasks.md
4. Update plan.md with fix strategy
5. Implement the fix
6. Update implement.md with fix details
7. Update clarify.md with resolution

#### Updating Specifications
1. Update specify.md with new specs
2. Update plan.md with implementation plan
3. Add tasks to tasks.md
4. Update analyze.md with impact analysis
5. Implement the changes
6. Update implement.md with details
7. Update clarify.md if issues were resolved

### Maintenance

#### Regular Updates
- **Weekly**: Review and update task status
- **Monthly**: Review and update plans
- **Quarterly**: Review and update analysis
- **As Needed**: Update when changes are made

#### Quality Checks
- **Consistency**: Check that all files are consistent
- **Completeness**: Ensure all information is included
- **Accuracy**: Verify information is correct
- **Clarity**: Make sure information is clear

#### Version Control
- **Commit Changes**: Commit updates regularly
- **Clear Messages**: Use descriptive commit messages
- **Review Changes**: Check changes before committing
- **Backup**: Keep backups of important changes