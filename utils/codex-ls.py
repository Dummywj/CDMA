#!/usr/bin/env python3
# Usage (from the project root): python3 utils/codex-ls.py
# Usage (explicit project): python3 utils/codex-ls.py /path/to/project
# Lists local sessions, including archived ones, without starting Codex.
# Uses CODEX_HOME when set, otherwise ~/.codex.

import argparse
import os
from pathlib import Path
import re
import sqlite3
import sys


def main():
    parser = argparse.ArgumentParser(
        description="List local Codex sessions whose working directory matches a project."
    )
    parser.add_argument(
        "project", nargs="?", default=".", help="project directory (default: current directory)"
    )
    args = parser.parse_args()
    project = Path(args.project).expanduser().resolve()
    if not project.is_dir():
        parser.error(f"Not a directory: {project}")

    codex_home = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
    databases = []
    for path in codex_home.glob("state_*.sqlite"):
        match = re.fullmatch(r"state_(\d+)\.sqlite", path.name)
        if match and path.is_file():
            databases.append((int(match.group(1)), path))
    if not databases:
        print(f"No Codex state database found in {codex_home}", file=sys.stderr)
        return 1

    # Codex versions its internal database filenames; prefer the newest schema.
    database = max(databases)[1].resolve()
    connection = None
    try:
        connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
        # Renaming sets name while preserving the original title.
        rows = connection.execute(
            "SELECT id, COALESCE(NULLIF(name, ''), title), archived FROM threads "
            "WHERE cwd = ? ORDER BY updated_at DESC",
            (str(project),),
        ).fetchall()
    except sqlite3.Error as error:
        print(f"Cannot query {database}: {error}", file=sys.stderr)
        return 1
    finally:
        if connection is not None:
            connection.close()

    print(f"Project: {project}")
    print(f"Sessions: {len(rows)}")
    if rows:
        print(f"{'SESSION ID':36}  {'ARCHIVED':8}  TITLE")
        for session_id, title, archived in rows:
            title = " ".join(title.split())
            print(f"{session_id:36}  {'yes' if archived else 'no':8}  {title}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
