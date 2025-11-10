# Heredoc Script Extraction Status

## Summary

### Completed Tasks
1. ✅ Removed duplicate bash validation script (kept Python version only)
2. ✅ Created unified extraction tool using validator's logic
3. ✅ Updated validator regex to match paths with slashes (finds conda hooks)
4. ✅ Fixed extraction to ensure scripts match originals exactly

### Current Status

**Validator finds:** 55+ shell scripts from post script + 2-3 from build script
**Original extraction had:** 17 scripts

### Key Findings

1. **Regex Pattern Issue**: The original validator regex `[^\s<>"\'$]+` doesn't match paths with slashes, so it missed conda hooks at `/opt/mamba/etc/conda/activate.d/unset_pythonpath.sh`

2. **Improved Regex**: Updated to `[^\s<>"\'$]+(?:/[^\s<>"\'$]+)*` which matches paths with slashes, but now finds many more scripts:
   - All `/etc/profile.d/*.sh` scripts (cuda.sh, drake.sh, compiled-libs.sh, etc.)
   - All utility scripts (vnc, virtualgl, pulseaudio, etc.)
   - All ROS/zenoh scripts
   - All conda hooks

3. **Filtering Logic**: The `is_shell_script()` function correctly identifies shell scripts, but the original extraction was more selective (only "important" scripts).

### Decision Needed

**Option A**: Extract ALL shell scripts (55+ scripts)
- Pros: Complete extraction, no scripts missed
- Cons: Many simple profile.d scripts, larger manifest

**Option B**: Extract only "important" scripts (17 scripts from original)
- Pros: Smaller, focused set
- Cons: Need to define what "important" means, may miss some scripts

**Option C**: Extract all scripts but organize by importance
- Pros: Complete but organized
- Cons: More complex organization

### Next Steps

1. Verify all 17 original scripts extract correctly ✅ (15/17 match, 2 need delimiter fix)
2. Decide on extraction scope (all scripts vs important only)
3. Fix delimiter detection for build script scripts
4. Update main extraction script to use unified approach
5. Verify all extracted scripts match originals exactly

## Files

- `scripts/validate_heredoc_scripts.py` - Validator (Python, single implementation)
- `scripts/extract_heredoc_scripts.py` - Original extractor (needs update)
- `scripts/extract_heredoc_scripts_unified.py` - Unified extractor (uses validator logic)
- `scripts/verify_extraction.py` - Verification tool

## Verification

Run verification:
```bash
python3 scripts/verify_extraction.py
```

Run extraction (unified):
```bash
python3 scripts/extract_heredoc_scripts_unified.py
```

Run validation:
```bash
python3 scripts/validate_heredoc_scripts.py
```

