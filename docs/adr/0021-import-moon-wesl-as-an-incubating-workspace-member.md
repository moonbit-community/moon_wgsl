# Import moon_wesl as an incubating workspace member

`Milky2018/moon_wesl` is imported under `modules/moon_wesl` from commit
`08fd313a638daa9b74245a9da5e3a51845a4fe40` of
`https://github.com/moonbit-community/moon_wesl`. The import contains only the
Git-tracked tree; repository metadata, dependency caches, and build products are
not copied.

The first integration stage preserves the imported implementation and package
version. The module participates in workspace checks and has a module-local CI
gate, but it is not added to the existing synchronized WGSL compatibility
release script. The old repository remains the package repository until a new
package version has been verified and published from this workspace.

The imported parser packages originally resolved `moonyacc` only from the
module-local dependency cache. A workspace may hoist that binary dependency to
an ancestor cache, so `tools/run-moonyacc.sh` resolves the nearest module or
workspace cache. Generated parser sources remain committed and unchanged.

The required dependency direction is `moon_wesl` to `wgsl`. WESL owns import
resolution, conditional compilation, module assembly, and WESL-specific syntax.
WGSL Core owns official WGSL parsing, validation, semantic IR, and emission.
The second integration stage removes the public WESL-owned `validate_wgsl`
surface and routes assembled WGSL through a private adapter over
`Milky2018/wgsl/ir`. WESL retains only extension parsing, module graph checks,
resolution, conditional compilation, lowering, and assembly. The same Core
boundary is used by `wesl check --kind wgsl`; source-local WESL checks perform
Core validation when no unresolved imports prevent assembly.

The Core validator now owns matrix scalar legality as an IR invariant. The
integration also fixed WESL lowering so global alias/constant substitutions are
applied only to declarations that semantically reference them, preserving local
shadowing. Transformation-only upstream fixtures explicitly disable final WGSL
validation when their expected output is intentionally not a valid shader.

After that seam is enforced, a release-preparation stage will review the public
API, update repository metadata, choose the next semantic version, publish the
new package from this repository, and only then deprecate the former repository.
