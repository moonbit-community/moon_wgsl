# Use separate semantic IR and Naga compatibility view

The workspace will keep WGSL Semantic IR separate from the Naga Compatibility View. WGSL Semantic IR represents program meaning, while the Naga Compatibility View models Naga-specific arenas, declaration ordering, temporary names, and writer plans; compatibility fields must not be folded back into the core IR as flags or provenance caches.

