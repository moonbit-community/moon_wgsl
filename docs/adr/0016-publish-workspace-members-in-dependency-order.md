# Publish workspace members in dependency order

The workspace release script will publish modules in dependency order: `wgsl`, `moon_wgsl_naga`, `moon_wgsl_naga_oil`, `moon_wgsl`, then `moon_wesl`. Registry metadata is refreshed between publishes so every dependent package resolves the just-published dependency version. A failed publish stops the script and reports the last completed module; it does not attempt automatic rollback because published package versions are external state.
