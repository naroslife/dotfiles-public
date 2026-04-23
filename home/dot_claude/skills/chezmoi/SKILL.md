---
name: chezmoi
description: Use whenever the user mentions chezmoi in any way. Manages dotfiles with chezmoi including tracking config files, comparing dotfiles, checking status, working with chezmoi templates, and handling local file changes. CRITICAL SAFETY RULES ENFORCED.
---

# Chezmoi Dotfiles Management

## When to Use
Use this skill when the user needs to:
- Track configuration file changes with chezmoi
- Compare local files with chezmoi-managed versions
- Check chezmoi status or differences
- Work with chezmoi templates (.tmpl files)
- Update dotfiles repository

## CRITICAL SAFETY RULES

**NEVER use these dangerous commands without explicit user confirmation:**
- `chezmoi apply` - Overwrites local changes with stored config (destructive!)
- `chezmoi apply --force` - Bypasses safety checks and destroys local changes silently
- Any command with `--force` flag

**Safe workflow:**
- `chezmoi add <file>` - Add local changes TO chezmoi tracking
- `chezmoi diff` - Compare tracked config with local files
- `chezmoi status` - Show files needing updates

## MANDATORY: Pull and Apply Workflow

When the user asks to pull and apply chezmoi (or any equivalent), ALWAYS follow this sequence. **Do not skip steps.**

### Step 1 — Check status
```bash
chezmoi status
```
Note any `MM` files (local changes that will be overwritten) and `DA` files (local files that will be deleted).

### Step 2 — If any MM or DA files exist, run full diff BEFORE pulling
```bash
chezmoi diff
```
Show this diff to the user and **explicitly warn** which local changes will be lost. Ask for confirmation before proceeding.

If there are no `MM` or `DA` files, you may proceed without confirmation.

### Step 3 — Pull
```bash
chezmoi git pull
```

### Step 4 — Show what the pull changed
```bash
chezmoi diff
```
Show the user what will be applied from the pull.

### Step 5 — Get explicit confirmation before applying
Tell the user exactly what will be overwritten and ask them to confirm. Do not apply until confirmed.

### Step 6 — Apply
```bash
chezmoi apply
```
Only use `--force` if chezmoi prompts interactively and cannot proceed otherwise, AND the user has already confirmed in Step 5.

## Common Commands

### Track Local Changes
```bash
chezmoi add ~/.config/hypr/hyprland.conf
```
This saves the current local file to chezmoi's source directory.

### Check What Changed
```bash
chezmoi diff
```
Shows differences between chezmoi's tracked version and local files.

### Check Status
```bash
chezmoi status
```
Lists files that differ between chezmoi source and local system.

### Test Template Rendering
```bash
chezmoi execute-template < ~/.local/share/chezmoi/dot_config/example.conf.tmpl
```
Previews how a template will render without applying it.

### Source Directory Location
Chezmoi source files are stored in `~/.local/share/chezmoi/`
- `dot_*` files become `.*` in home directory
- `.tmpl` files are processed as Go templates

## Workflow Pattern

1. **User edits local config file** (e.g., `~/.bashrc`)
2. **Add changes to chezmoi:** `chezmoi add ~/.bashrc`
3. **Verify with diff:** `chezmoi diff` (optional)
4. **Commit changes:** Standard git operations in `~/.local/share/chezmoi/`

## Handling Local Changes to Template Files

When a user reports that their local file has changes that differ from the chezmoi template:

### Critical Understanding
The user has ALREADY made changes to their local file and wants the template updated to MATCH those changes. Do NOT suggest applying the template to overwrite their local changes.

**CRITICAL - Template Conditionals:**
- **NEVER remove template conditionals** (e.g., `{{ if .is_work }}...{{ end }}`) from .tmpl files unless EXPLICITLY requested
- Template conditionals exist for environment-specific logic and should be preserved
- When updating templates to match local changes, preserve all existing conditionals and template variables
- If the local file differs from the template due to conditional logic, the LOCAL file should be updated to match the template logic, NOT the other way around
- Only when the user explicitly says to remove or modify conditionals should they be changed

### Step-by-Step Process

1. **Identify the exact local changes:**
   ```bash
   chezmoi diff ~/.config/path/to/file
   ```

2. **Find the template source file:**
   ```bash
   chezmoi source-path ~/.config/path/to/file
   ```

3. **Check modification timestamps:**
   ```bash
   stat -c '%y %n' ~/.config/path/to/file && chezmoi source-path ~/.config/path/to/file | xargs stat -c '%y %n'
   ```

4. **Read both files to understand the exact difference**

5. **Confirm with user if needed** — present timestamp info and ask which direction to sync

6. **Use `chezmoi add` for non-template files** — preferred method for simple files

7. **For template files, update manually** — edit the template file directly, preserving all conditionals and variables

8. **Verify the fix:**
   ```bash
   chezmoi diff ~/.config/path/to/file
   ```
   Should show NO diff if the template was updated correctly.

### Understanding chezmoi diff output

- Lines with `-` prefix: Content in chezmoi's SOURCE (template)
- Lines with `+` prefix: Content in the TARGET (actual local file)
- The `-`/`+` symbols show LOCATION (source vs target), NOT time (old vs new)
- Always check timestamps to determine which direction to sync

## Template Variables

Access chezmoi data in templates:
```
{{ .chezmoi.hostname }}
{{ .chezmoi.os }}
{{ .chezmoi.username }}
```

## Error Handling

If chezmoi commands fail:
- Check if file is tracked: `chezmoi managed | grep filename`
- Verify source directory: `ls ~/.local/share/chezmoi/`
- Check for template errors: `chezmoi execute-template` on specific file

## When NOT to Use Chezmoi

Do not use chezmoi commands for:
- Files not in the dotfiles repository
- Temporary files or caches
- Files with secrets (use chezmoi's encrypted files feature instead)
