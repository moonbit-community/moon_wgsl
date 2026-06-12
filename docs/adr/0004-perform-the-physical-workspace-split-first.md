# Perform the physical workspace split first

The repository will do the module/workspace split as an atomic migration before incremental cleanup inside the old single-module layout. This creates a larger one-time diff, but avoids keeping a long-lived half-split architecture where package ownership, import paths, and publish boundaries remain ambiguous.

