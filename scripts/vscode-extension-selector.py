#!/usr/bin/env python
"""
VSCode Extension Selector - Interactive TUI for managing VSCode extensions.

Features:
- Browse extensions organized by category
- Preview extension details
- Multi-select with checkboxes
- Preserves commented extensions
- Automatic backup before saving
"""

import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import (
    Button,
    Checkbox,
    Footer,
    Header,
    Label,
    Static,
    Tree,
)
from textual.widgets.tree import TreeNode


@dataclass
class Extension:
    """Represents a VSCode extension."""

    id: str
    description: str
    category: str
    nix: Optional[str] = None
    is_active: bool = False
    is_commented: bool = False

    @property
    def status(self) -> str:
        """Get status symbol."""
        if self.is_active:
            return "✓"
        elif self.is_commented:
            return "#"
        return "○"

    @property
    def status_text(self) -> str:
        """Get status description."""
        if self.is_active:
            return "Currently Active"
        elif self.is_commented:
            return "Commented Out"
        return "Not Configured"


@dataclass
class Category:
    """Represents an extension category."""

    name: str
    extensions: List[Extension]

    @property
    def active_count(self) -> int:
        """Count active extensions in this category."""
        return sum(1 for ext in self.extensions if ext.is_active)

    @property
    def total_count(self) -> int:
        """Total extensions in this category."""
        return len(self.extensions)


class ExtensionPreview(Static):
    """Preview panel showing extension details."""

    def __init__(self) -> None:
        super().__init__()
        self.extension: Optional[Extension] = None

    def update_preview(self, extension: Optional[Extension]) -> None:
        """Update the preview with extension details."""
        self.extension = extension
        if extension is None:
            self.update("Select an extension to preview")
            return

        lines = [
            f"[bold cyan]Extension:[/bold cyan] {extension.id}",
            f"[bold]Category:[/bold] {extension.category.title()}",
            f"[bold]Status:[/bold] {extension.status} {extension.status_text}",
            "",
            f"[bold]Description:[/bold]",
            f"{extension.description}",
        ]

        if extension.nix:
            lines.extend(["", f"[dim]Nix package:[/dim] {extension.nix}"])
        else:
            lines.extend(["", "[dim]Nix package: Not available[/dim]"])

        self.update("\n".join(lines))


class ExtensionSelector(App):
    """Main TUI application for selecting VSCode extensions."""

    CSS = """
    Screen {
        layout: grid;
        grid-size: 2 2;
        grid-rows: auto 1fr;
    }

    Header {
        column-span: 2;
    }

    #extensions-panel {
        height: 100%;
        border: solid $primary;
        padding: 1;
    }

    #preview-panel {
        height: 100%;
        border: solid $accent;
        padding: 1;
    }

    Tree {
        height: 100%;
    }

    ExtensionPreview {
        height: 100%;
    }

    .category-header {
        text-style: bold;
        color: $accent;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("escape", "quit", "Quit"),
        Binding("s", "save", "Save"),
        Binding("enter", "save", "Save"),
        Binding("a", "select_all", "Select All"),
        Binding("d", "deselect_all", "Deselect All"),
        Binding("space", "toggle_current", "Toggle", show=False),
    ]

    TITLE = "🎨 VSCode Extension Selector"

    def __init__(self) -> None:
        super().__init__()
        self.script_dir = Path(__file__).parent
        self.dotfiles_dir = self.script_dir.parent
        self.extensions_json = Path(
            os.environ.get(
                "EXTENSIONS_JSON",
                self.dotfiles_dir / ".vscode" / "extensions.json",
            )
        )
        self.data_file = self.script_dir / "vscode-extension-data.json"

        self.categories: List[Category] = []
        self.extensions_by_id: Dict[str, Extension] = {}
        self.selected_ids: Set[str] = set()
        self.extensions_tree: Optional[Tree] = None
        self.preview: Optional[ExtensionPreview] = None
        self.extensions_label: Optional[Label] = None

    def compose(self) -> ComposeResult:
        """Compose the UI layout."""
        yield Header()

        with Vertical(id="extensions-panel"):
            self.extensions_label = Label(f"Extensions ({len(self.extensions_by_id)} total)")
            yield self.extensions_label
            self.extensions_tree = Tree("Extensions")
            yield self.extensions_tree

        with Vertical(id="preview-panel"):
            yield Label("Preview")
            self.preview = ExtensionPreview()
            yield self.preview

        yield Footer()

    def on_mount(self) -> None:
        """Load data and populate tree on mount."""
        try:
            self.load_data()
            self.update_extensions_count()
            self.populate_tree()
        except Exception as e:
            self.exit(message=f"Error loading data: {e}")

    def load_data(self) -> None:
        """Load extensions from JSON files."""
        # Load extension metadata
        with open(self.data_file) as f:
            data = json.load(f)

        # Load current extensions.json
        active_ids, commented_ids = self.parse_extensions_json()

        # Create extension objects
        extensions_dict: Dict[str, List[Extension]] = {}

        for ext_data in data["extensions"]:
            ext_id = ext_data["id"]
            extension = Extension(
                id=ext_id,
                description=ext_data.get("description", ""),
                category=ext_data.get("category", "unknown"),
                nix=ext_data.get("nix"),
                is_active=ext_id in active_ids,
                is_commented=ext_id in commented_ids,
            )

            self.extensions_by_id[ext_id] = extension

            if extension.category not in extensions_dict:
                extensions_dict[extension.category] = []
            extensions_dict[extension.category].append(extension)

            # Track active extensions
            if extension.is_active:
                self.selected_ids.add(ext_id)

        # Add extensions from JSON that aren't in data file
        all_json_ids = active_ids | commented_ids
        missing_ids = all_json_ids - set(self.extensions_by_id.keys())

        for ext_id in missing_ids:
            extension = Extension(
                id=ext_id,
                description="(not in database)",
                category="unknown",
                is_active=ext_id in active_ids,
                is_commented=ext_id in commented_ids,
            )
            self.extensions_by_id[ext_id] = extension

            if "unknown" not in extensions_dict:
                extensions_dict["unknown"] = []
            extensions_dict["unknown"].append(extension)

            if extension.is_active:
                self.selected_ids.add(ext_id)

        # Create categories
        for cat_name in sorted(extensions_dict.keys()):
            category = Category(
                name=cat_name, extensions=sorted(extensions_dict[cat_name], key=lambda e: e.id)
            )
            self.categories.append(category)

    def update_extensions_count(self) -> None:
        """Update the extensions count label."""
        if self.extensions_label:
            self.extensions_label.update(f"Extensions ({len(self.extensions_by_id)} total)")

    def parse_extensions_json(self) -> tuple[Set[str], Set[str]]:
        """Parse extensions.json to find active and commented extensions."""
        active_ids = set()
        commented_ids = set()

        if not self.extensions_json.exists():
            return active_ids, commented_ids

        with open(self.extensions_json) as f:
            for line in f:
                line = line.strip()

                # Skip empty lines and non-extension lines
                if not line or not ('"' in line):
                    continue

                # Check if line is commented
                is_commented = line.lstrip().startswith("//")

                # Extract extension ID
                parts = line.split('"')
                if len(parts) >= 2:
                    ext_id = parts[1]

                    if is_commented:
                        commented_ids.add(ext_id)
                    else:
                        active_ids.add(ext_id)

        return active_ids, commented_ids

    def populate_tree(self) -> None:
        """Populate the tree with categories and extensions."""
        if not self.extensions_tree:
            return

        self.extensions_tree.clear()
        root = self.extensions_tree.root

        for category in self.categories:
            cat_label = f"{category.name.title()} [{category.active_count}/{category.total_count}]"
            cat_node = root.add(cat_label, expand=True)
            cat_node.data = {"type": "category", "category": category}

            for extension in category.extensions:
                # Create checkbox label
                checked = "✓" if extension.id in self.selected_ids else " "
                ext_label = f"[{checked}] {extension.id}"

                ext_node = cat_node.add_leaf(ext_label)
                ext_node.data = {"type": "extension", "extension": extension}

    def on_tree_node_selected(self, event: Tree.NodeSelected) -> None:
        """Handle tree node selection."""
        node = event.node

        if node.data and node.data["type"] == "extension":
            extension = node.data["extension"]
            if self.preview:
                self.preview.update_preview(extension)

    def on_tree_node_highlighted(self, event: Tree.NodeHighlighted) -> None:
        """Handle tree node highlight (cursor moved)."""
        node = event.node

        if node and node.data and node.data["type"] == "extension":
            extension = node.data["extension"]
            if self.preview:
                self.preview.update_preview(extension)
        elif node and node.data and node.data["type"] == "category":
            if self.preview:
                self.preview.update_preview(None)

    def action_toggle_current(self) -> None:
        """Toggle selection for the current extension."""
        if not self.extensions_tree or not self.extensions_tree.cursor_node:
            return

        node = self.extensions_tree.cursor_node

        if node.data and node.data["type"] == "extension":
            extension = node.data["extension"]

            if extension.id in self.selected_ids:
                self.selected_ids.remove(extension.id)
            else:
                self.selected_ids.add(extension.id)

            self.refresh_tree()

    def action_select_all(self) -> None:
        """Select all extensions."""
        self.selected_ids = set(self.extensions_by_id.keys())
        self.refresh_tree()

    def action_deselect_all(self) -> None:
        """Deselect all extensions."""
        self.selected_ids.clear()
        self.refresh_tree()

    def refresh_tree(self) -> None:
        """Refresh tree display."""
        if not self.extensions_tree:
            return

        # Store current cursor position
        current_node = self.extensions_tree.cursor_node

        # Repopulate tree
        self.populate_tree()

        # Try to restore cursor position
        # (This is simplified; full restoration would need more tracking)

    def action_save(self) -> None:
        """Save selection to extensions.json."""
        try:
            self.save_extensions()
            self.exit(message=f"✓ Saved {len(self.selected_ids)} extensions to {self.extensions_json}")
        except Exception as e:
            self.exit(message=f"Error saving: {e}")

    def save_extensions(self) -> None:
        """Generate and save extensions.json."""
        # Backup existing file
        if self.extensions_json.exists():
            backup_path = self.extensions_json.with_suffix(
                f".json.backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            )
            self.extensions_json.rename(backup_path)

        # Organize selected extensions by category
        selected_by_category: Dict[str, List[Extension]] = {}

        for ext_id in sorted(self.selected_ids):
            extension = self.extensions_by_id[ext_id]
            category = extension.category

            if category not in selected_by_category:
                selected_by_category[category] = []
            selected_by_category[category].append(extension)

        # Generate JSON content
        lines = ["{", '    "recommendations": [']

        first_category = True
        for category in sorted(selected_by_category.keys()):
            extensions = selected_by_category[category]

            if not first_category:
                lines[-1] += ","
            lines.extend(["", f"        // {category.title()}"])

            for i, extension in enumerate(extensions):
                comma = "," if i < len(extensions) - 1 else ""
                if extension.description and extension.description != "(not in database)":
                    lines.append(f'        "{extension.id}"{comma} // {extension.description}')
                else:
                    lines.append(f'        "{extension.id}"{comma}')

            first_category = False

        # Add commented extensions that weren't selected
        active_ids, commented_ids = self.parse_extensions_json()
        unselected_commented = commented_ids - self.selected_ids

        if unselected_commented:
            lines.extend(
                [
                    "",
                    "",
                    "        // ============= OPTIONAL/DISABLED EXTENSIONS =============",
                    "        // Uncomment any of these if you need them for specific projects",
                ]
            )

            for ext_id in sorted(unselected_commented):
                extension = self.extensions_by_id.get(ext_id)
                if extension and extension.description and extension.description != "(not in database)":
                    lines.append(f'        // "{ext_id}", // {extension.description}')
                else:
                    lines.append(f'        // "{ext_id}"')

        lines.extend(["    ]", "}"])

        # Write to file
        self.extensions_json.parent.mkdir(parents=True, exist_ok=True)
        with open(self.extensions_json, "w") as f:
            f.write("\n".join(lines) + "\n")


def main() -> None:
    """Entry point."""
    app = ExtensionSelector()
    app.run()


if __name__ == "__main__":
    main()
