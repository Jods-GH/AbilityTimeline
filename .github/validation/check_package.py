"""Reject development files in every archive produced by the addon packager."""

from pathlib import Path, PurePosixPath
import sys
import zipfile


def check_package(directory):
    archives = sorted(Path(directory).glob("*.zip"))
    if not archives:
        raise ValueError("No package archives found")
    forbidden = {"spec", ".github", ".busted", ".luacheckrc", "Dockerfile"}
    for archive in archives:
        with zipfile.ZipFile(archive) as package:
            names = package.namelist()
            if "AbilityTimeline/AbilityTimeline.toc" not in names:
                raise ValueError(f"{archive.name}: addon TOC missing")
            for name in names:
                parts = PurePosixPath(name.replace("\\", "/")).parts
                if forbidden.intersection(parts):
                    raise ValueError(f"{archive.name}: development file shipped: {name}")
        print(f"Package contents OK: {archive.name}")


if __name__ == "__main__":
    try:
        check_package(sys.argv[1])
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
