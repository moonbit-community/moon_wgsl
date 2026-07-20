# moon_wgsl developer tools

This workspace-only module contains command line tools used by repository
checks. It is not part of the public package split and is not published by the
multi-module release script.

`check_release_archives.sh` packages every publishable module, verifies the WGSL
and WESL zip files, then tests those two archives together in a fresh workspace.
This catches dependency-version and build-script assumptions hidden by the
repository's source workspace.
