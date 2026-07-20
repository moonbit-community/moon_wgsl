# Manage moon_wesl as a first-class workspace module

`Milky2018/moon_wesl` is maintained as a first-class module of the `moon_wgsl`
workspace. Its source, CI, architecture checks, release archive verification,
and future development belong to this repository. The former standalone
repository is migration history and may be deprecated after its replacement
package has been published from this workspace.

WESL keeps its existing module identity and independent semantic version. It is
not folded into the `Milky2018/moon_wgsl` facade and does not join the
synchronized WGSL compatibility version line. This preserves a small public
interface for composition users while allowing WESL to evolve according to its
own compatibility requirements.

The imported `cmd/wesl` executable package is removed. This workspace publishes
libraries rather than a separate WESL command-line product, and every useful
operation previously wrapped by the command is already available through the
`moon_wesl` library interface. CLI compatibility with the upstream `wesl-cli`
crate is therefore outside the workspace product boundary.

The dependency direction remains `moon_wesl` to `wgsl`. WESL owns extension
syntax, module resolution, conditional compilation, lowering, and source
assembly. WGSL Core owns official WGSL parsing, validation, semantic IR, and
emission. Consumers that need command-line tooling can build it over the public
library interface without introducing a second owner of either set of
semantics.
