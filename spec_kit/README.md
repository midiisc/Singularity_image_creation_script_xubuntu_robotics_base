# Spec Kit Specification Folder

This folder contains specifications and documentation for the Xubuntu Robotics Base image build system.

## Purpose
- Store detailed specifications for the build system
- Document requirements and configurations
- Maintain version-specific specifications
- Provide reference materials for development

## Structure
```
spec_kit/
├── README.md                    # This file
├── constitution.md              # Core principles and rules
├── specify.md                   # Current specifications
├── clarify.md                   # Issues resolved and clarifications
├── plan.md                      # Development plan and roadmap
├── tasks.md                     # Current and future tasks
├── analyze.md                   # Analysis and conflict resolution
├── implement.md                 # Implementation status and details
├── build_specifications.md     # Build system specifications
├── software_versions.md        # Software version requirements
├── hardware_requirements.md    # Hardware specifications
├── WORKFLOW_GUIDE.md           # Workflow guide and usage
└── configuration_templates/    # Configuration templates
```

## Related Documentation

- **Rules System**: `.cursor/rules/*.mdc` (source of truth, automatically enforced)
- **Global Settings**: `docs/GLOBAL_CURSOR_SETTINGS.md`
- **Repository README**: `README.md` (AI Agent Protocols section)
- **Audit System**: `.cursor/README.md`, `.cursor/setup-audit-for-other-projects.md`

## Usage
- Add new specification files as needed
- Keep specifications up to date with changes
- Use for documentation and reference
- Share with team members for consistency

## Note
This folder is for specifications and documentation only. Core functional files remain in the repository root.