#!/usr/bin/env python
"""
Claude Session Escape Sequence Cleaner

Removes terminal escape sequences from Claude session files that can cause
mouse tracking issues and other terminal state problems.

Usage:
  claude-session-cleaner file.jsonl                    # Clean single file
  claude-session-cleaner /path/to/sessions/            # Clean all .jsonl files in folder
  claude-session-cleaner /path/to/sessions/ --recursive # Clean recursively
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple


def clean_escape_sequences(text: str) -> str:
    """Remove all terminal escape sequences including mouse tracking queries."""

    # All possible escape sequence patterns
    patterns = [
        # Standard ANSI sequences
        r"\\u001b\[[\d;]*m",  # Color codes
        r"\\u001b\[[\d;]*[HJKABCDEFGPST]",  # Cursor movement, clear screen, etc.
        # Private mode sequences (the dangerous ones for mouse tracking)
        r"\\u001b\[\?[\d]+[hl]",  # Private mode set/reset (like ?1049l, ?1000h)
        r"\\u001b\[\?[\d]+\$[p]",  # Private mode queries (like ?2048$p)
        # Cursor position and other query sequences
        r"\\u001b\[>[\d]*[a-zA-Z]",  # Device status queries (like >1u)
        r"\\u001b\[[\d;]*[nR]",  # Position reports
        # Window title sequences
        r"\\u001b\][0-2];[^\\u001b]*\\u001b\\\\",  # OSC sequences
        # Literal escape sequences in Python strings
        r"\\\\033\[[\d;]*m",
        r"\\\\033\[[\d;]*[HJKABCDEFGPST]",
        r"\\\\033\[\?[\d]+[hl]",
        r"\\\\033\[\?[\d]+\$[p]",
        r"\\\\033\[>[\d]*[a-zA-Z]",
        r"\\\\033\[[\d;]*[nR]",
        r"\\\\033\][0-2];[^\\\\033]*\\\\033\\\\\\\\",
        # Additional color sequences that might be missed
        r"\\u001b\[[\d;]*;[\d;]*;[\d;]*;[\d;]*;[\d;]*m",  # Extended color sequences
        # Catch-all for any remaining sequences
        r"\\u001b\[[^a-zA-Z]*[a-zA-Z]",
        r"\\\\033\[[^a-zA-Z]*[a-zA-Z]",
    ]

    cleaned_text = text
    for pattern in patterns:
        cleaned_text = re.sub(pattern, "", cleaned_text)

    return cleaned_text


def count_escape_sequences(text: str) -> int:
    """Count escape sequences in text."""
    escape_patterns = [
        r"\\u001b\[[^a-zA-Z]*[a-zA-Z]",
        r"\\\\033\[[^a-zA-Z]*[a-zA-Z]",
    ]

    count = 0
    for pattern in escape_patterns:
        count += len(re.findall(pattern, text))
    return count


def clean_file(file_path: Path, backup: bool = True) -> Tuple[int, int]:
    """
    Clean a single session file.
    Returns (sequences_before, sequences_after)
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        before_count = count_escape_sequences(content)

        if before_count == 0:
            return 0, 0

        # Create backup if requested
        if backup:
            backup_path = file_path.with_suffix(f"{file_path.suffix}.backup")
            backup_path.write_text(content, encoding="utf-8")

        cleaned_content = clean_escape_sequences(content)
        after_count = count_escape_sequences(cleaned_content)

        # Write cleaned content back
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(cleaned_content)

        return before_count, after_count

    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}", file=sys.stderr)
        return 0, 0


def find_session_files(path: Path, recursive: bool = False) -> List[Path]:
    """Find all .jsonl session files in path."""
    if path.is_file():
        return [path] if path.suffix == ".jsonl" else []

    pattern = "**/*.jsonl" if recursive else "*.jsonl"
    return list(path.glob(pattern))


def main():
    parser = argparse.ArgumentParser(
        description="Clean escape sequences from Claude session files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage:")[1] if "Usage:" in __doc__ else "",
    )

    parser.add_argument(
        "path",
        type=Path,
        help="File or directory path to clean"
    )

    parser.add_argument(
        "--recursive",
        "-r",
        action="store_true",
        help="Recursively process subdirectories"
    )

    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Don't create backup files"
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be cleaned without modifying files"
    )

    args = parser.parse_args()

    if not args.path.exists():
        print(f"❌ Path does not exist: {args.path}", file=sys.stderr)
        sys.exit(1)

    # Find session files
    session_files = find_session_files(args.path, args.recursive)

    if not session_files:
        print(f"No .jsonl files found in {args.path}")
        sys.exit(0)

    print(f"🔍 Found {len(session_files)} session file(s) to process")

    total_removed = 0
    files_cleaned = 0

    for file_path in session_files:
        if args.dry_run:
            try:
                content = file_path.read_text(encoding="utf-8")
                before_count = count_escape_sequences(content)
                if before_count > 0:
                    print(f"📄 {file_path.name}: {before_count} escape sequences (dry run)")
                    files_cleaned += 1
                    total_removed += before_count
            except Exception as e:
                print(f"❌ Error reading {file_path}: {e}", file=sys.stderr)
        else:
            before_count, after_count = clean_file(
                file_path, backup=not args.no_backup
            )

            if before_count > 0:
                removed = before_count - after_count
                print(f"✅ {file_path.name}: removed {removed} escape sequences")
                files_cleaned += 1
                total_removed += removed
            else:
                print(f"✓ {file_path.name}: already clean")

    if args.dry_run:
        print(f"\n🔍 Dry run complete: {total_removed} escape sequences in {files_cleaned} files")
    else:
        print(f"\n🎉 Cleaned {files_cleaned} files, removed {total_removed} escape sequences total")

        if not args.no_backup and files_cleaned > 0:
            print("💾 Backup files created with .backup extension")


if __name__ == "__main__":
    main()
