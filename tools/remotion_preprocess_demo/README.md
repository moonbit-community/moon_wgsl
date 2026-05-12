# moon_wgsl Preprocess Demo

This Remotion project renders a short promo clip for the `moon_wgsl`
preprocessing flow.

## Story

1. Start with a WGSL file containing `#ifdef USE_TEXTURE`.
2. Expand the scene into multiple source files: shared declarations, material
   options, and the composer entry point.
3. Show MoonBit code setting shader definitions and running the preprocessor.
4. Animate live source lines flowing into the preprocessor.
5. Reveal the clean preprocessed WGSL that the composer receives.

## Commands

```bash
npm install
npm run still
npm run render
```

The rendered video is written to `out/preprocess-demo.mp4`.

## Voiceover Script

moon_wgsl lets MoonBit projects preprocess WGSL before composition. Several
shader files enter the composer graph, MoonBit enables `USE_TEXTURE`, and the
preprocessor resolves imports while folding conditional branches. The result is
clean WGSL ready for registration, validation, and rendering, with shader
variants kept explicit, testable, and close to application code.
