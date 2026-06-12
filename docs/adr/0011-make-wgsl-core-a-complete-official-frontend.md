# Make WGSL Core a complete official frontend

`Milky2018/wgsl` will target a complete official WGSL frontend rather than a parser subset tailored to composer needs. Parser acceptance, semantic validation, and IR lowering should be separated so WGSL language rules are enforced before compatibility modules transform or emit code.

