# Import moon_wesl as an incubating workspace member

Status: superseded by ADR 0022 after the staged import and WGSL Core integration
completed. This record retains the constraints of the original import decision.

`Milky2018/moon_wesl` is imported under `modules/moon_wesl` from commit
`08fd313a638daa9b74245a9da5e3a51845a4fe40` of
`https://github.com/moonbit-community/moon_wesl`. The import contains only the
Git-tracked tree; repository metadata, dependency caches, and build products are
not copied.

The first integration stage preserved the imported implementation and package
version without adding it to the synchronized WGSL compatibility release line.
Release preparation adds it to the workspace release script with an independent
version argument. The old repository remains available until a new package
version has been verified and published from this workspace.

The imported parser packages originally resolved `moonyacc` from a physical
dependency-cache path. WGSL Core had the same workspace-layout assumption.
Each published module now owns module-level `rule` declarations that invoke
the pinned `moonbitlang/yacc@0.7.17` through `moon runwasm`; parser packages
reference those rules with `dev_build`. Parser generation therefore does not
depend on shell wrappers, cache placement, or the consumer's target backend.
Generated parser sources remain committed.

CI extracts the WGSL and WESL archives into a fresh workspace and runs the
WESL/Core tests against only those packaged sources.

The required dependency direction is `moon_wesl` to `wgsl`. WESL owns import
resolution, conditional compilation, module assembly, and WESL-specific syntax.
WGSL Core owns official WGSL parsing, validation, semantic IR, and emission.
The second integration stage removes the public WESL-owned `validate_wgsl`
surface and routes assembled WGSL through a private adapter over
`Milky2018/wgsl/ir`. WESL retains only extension parsing, module graph checks,
resolution, conditional compilation, lowering, and assembly. The imported CLI
used the same Core boundary during migration and was later removed when ADR
0022 established the workspace's library-only WESL product boundary.

The Core validator now owns matrix scalar legality as an IR invariant. The
integration also fixed WESL lowering so global alias/constant substitutions are
applied only to declarations that semantically reference them, preserving local
shadowing. Transformation-only upstream fixtures explicitly disable final WGSL
validation when their expected output is intentionally not a valid shader.

After that seam is enforced, a release-preparation stage will review the public
API, update repository metadata, choose the next semantic version, publish the
new package from this repository, and only then deprecate the former repository.

The public API comparison against 0.1.2 removes only `validate_wgsl`, which is a
breaking change. The first workspace-owned replacement is therefore prepared as
0.2.0. It pins WGSL Core 0.16.1, whose patch-level matrix validation correction
is required for equivalent behavior outside the source workspace. Its package
repository points to `moonbit-community/moon_wgsl`; the old repository remains
available until 0.2.0 has actually been published.

The imported `README.md -> README.mbt.md` symlink is removed during release
preparation. Like the other publishable workspace modules, `moon.mod` now points
directly to `README.mbt.md`, so the temporary source-symlink exception can be
removed without adding another repository mechanism.
