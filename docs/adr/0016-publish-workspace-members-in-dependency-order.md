# Publish workspace members in dependency order

The workspace release script will publish modules in dependency order: `wgsl`, `moon_wgsl_naga`, `moon_wgsl_naga_oil`, then `moon_wgsl`. A failed publish stops the script and reports the last completed module; it does not attempt automatic rollback because published package versions are external state.

