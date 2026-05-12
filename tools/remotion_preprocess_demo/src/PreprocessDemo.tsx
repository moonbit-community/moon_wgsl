import React from 'react';
import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

type SourceFile = {
  name: string;
  subtitle: string;
  lines: Array<{text: string; kind?: 'directive' | 'active' | 'inactive' | 'import'}>;
};

type MovingLine = {
  text: string;
  from: {x: number; y: number};
  to: {x: number; y: number};
  color: string;
  delay: number;
};

const sourceFiles: SourceFile[] = [
  {
    name: 'common.wgsl',
    subtitle: 'shared imports',
    lines: [
      {text: '#define_import_path demo::common', kind: 'directive'},
      {text: 'struct VertexOut {', kind: 'active'},
      {text: '  @location(0) uv: vec2<f32>,', kind: 'active'},
      {text: '}', kind: 'active'},
    ],
  },
  {
    name: 'material.wgsl',
    subtitle: 'shader option',
    lines: [
      {text: '#define_import_path demo::material', kind: 'directive'},
      {text: '#ifdef USE_TEXTURE', kind: 'directive'},
      {text: 'var base_color: texture_2d<f32>;', kind: 'active'},
      {text: '#else', kind: 'directive'},
      {text: 'let base_color = vec4<f32>(1.0);', kind: 'inactive'},
      {text: '#endif', kind: 'directive'},
    ],
  },
  {
    name: 'sprite.wgsl',
    subtitle: 'composer entry',
    lines: [
      {text: '#import demo::common::VertexOut', kind: 'import'},
      {text: '#import demo::material::base_color', kind: 'import'},
      {text: '@fragment'},
      {text: 'fn fragment(in: VertexOut) -> vec4<f32> {', kind: 'active'},
      {text: '  return sample_base_color(in.uv);', kind: 'active'},
      {text: '}', kind: 'active'},
    ],
  },
];

const moonbitLines = [
  'let defs = @common.default_wgsl_value_defines()',
  'defs.set("USE_TEXTURE", @common.ShaderDefValue::Bool(true))',
  '',
  'let preprocessed = @preprocess.Preprocessor::default()',
  '  .preprocess(source, defs)',
  '',
  'composer.register_source("sprite.wgsl", preprocessed.preprocessed_source)',
  'let wgsl = composer.make_naga_module("demo::sprite")',
];

const outputLines = [
  'struct VertexOut {',
  '  @location(0) uv: vec2<f32>,',
  '}',
  '',
  'var base_color: texture_2d<f32>;',
  '',
  '@fragment',
  'fn fragment(in: VertexOut) -> vec4<f32> {',
  '  return sample_base_color(in.uv);',
  '}',
];

const colors = {
  bg: '#071114',
  panel: '#102026',
  panel2: '#0b181d',
  border: '#21454e',
  text: '#e8fbff',
  muted: '#8ba7ad',
  cyan: '#45d5ff',
  green: '#72f1a8',
  amber: '#ffd166',
  red: '#ff6b7a',
  blue: '#89b4ff',
};

const timing = {
  moonbitIn: 82,
  processStart: 150,
  outputStart: 228,
  finalStart: 326,
};

const cardPositions = [
  {x: 130, y: 270, w: 575},
  {x: 680, y: 355, w: 575},
  {x: 1230, y: 270, w: 575},
];

const movingLines: MovingLine[] = [
  {
    text: 'struct VertexOut {',
    from: {x: 178, y: 412},
    to: {x: 990, y: 333},
    color: colors.text,
    delay: 0,
  },
  {
    text: '@location(0) uv: vec2<f32>,',
    from: {x: 178, y: 448},
    to: {x: 990, y: 369},
    color: colors.text,
    delay: 8,
  },
  {
    text: 'var base_color: texture_2d<f32>;',
    from: {x: 728, y: 535},
    to: {x: 990, y: 477},
    color: colors.green,
    delay: 16,
  },
  {
    text: '@fragment',
    from: {x: 1278, y: 416},
    to: {x: 990, y: 585},
    color: colors.blue,
    delay: 24,
  },
  {
    text: 'fn fragment(...) -> vec4<f32> {',
    from: {x: 1278, y: 452},
    to: {x: 990, y: 621},
    color: colors.text,
    delay: 32,
  },
  {
    text: 'return sample_base_color(in.uv);',
    from: {x: 1278, y: 488},
    to: {x: 990, y: 657},
    color: colors.text,
    delay: 40,
  },
];

export const PreprocessDemo: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const titleIn = spring({frame, fps, config: {damping: 18, stiffness: 110}});
  const moonbitProgress = spring({
    frame: frame - timing.moonbitIn,
    fps,
    config: {damping: 18, stiffness: 120},
  });
  const processProgress = spring({
    frame: frame - timing.processStart,
    fps,
    config: {damping: 19, stiffness: 100},
  });
  const outputProgress = spring({
    frame: frame - timing.outputStart,
    fps,
    config: {damping: 20, stiffness: 95},
  });
  const finalProgress = spring({
    frame: frame - timing.finalStart,
    fps,
    config: {damping: 20, stiffness: 90},
  });

  const sourceScale = interpolate(outputProgress, [0, 1], [1, 0.76], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const sourceOpacity = interpolate(finalProgress, [0, 1], [1, 0.28], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const sourceY = interpolate(outputProgress, [0, 1], [0, -118], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background:
          'radial-gradient(circle at 20% 12%, rgba(69,213,255,0.18), transparent 26%), radial-gradient(circle at 82% 78%, rgba(114,241,168,0.12), transparent 30%), linear-gradient(135deg, #071114 0%, #0b1a1f 58%, #061012 100%)',
        color: colors.text,
        fontFamily:
          'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
        overflow: 'hidden',
      }}
    >
      <Grid />
      <Header progress={titleIn} frame={frame} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: sourceOpacity,
          transform: `translateY(${sourceY}px) scale(${sourceScale})`,
          transformOrigin: '960px 430px',
        }}
      >
        {sourceFiles.map((file, index) => (
          <SourceCard
            key={file.name}
            file={file}
            index={index}
            processProgress={processProgress}
          />
        ))}
      </div>
      <MoonBitConsole
        progress={moonbitProgress}
        processProgress={processProgress}
        finalProgress={finalProgress}
      />
      <Processor frame={frame} progress={processProgress} />
      <FlowLayer progress={processProgress} outputProgress={outputProgress} />
      <OutputPanel progress={outputProgress} finalProgress={finalProgress} />
      <Footer frame={frame} />
    </AbsoluteFill>
  );
};

const Header: React.FC<{progress: number; frame: number}> = ({progress, frame}) => {
  const captionOpacity = interpolate(frame, [28, 68], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        top: 50,
        left: 112,
        opacity: progress,
        transform: `translateY(${(1 - progress) * 22}px)`,
      }}
    >
      <div
        style={{
          color: colors.cyan,
          fontSize: 25,
          fontWeight: 760,
          letterSpacing: 0,
          marginBottom: 8,
        }}
      >
        moon_wgsl composer
      </div>
      <div style={{fontSize: 58, fontWeight: 780, letterSpacing: 0}}>
        Preprocess shader sources before composition
      </div>
      <div style={{fontSize: 24, color: colors.muted, marginTop: 10, opacity: captionOpacity}}>
        Multiple WGSL files enter. MoonBit shader definitions decide the final source.
      </div>
    </div>
  );
};

const SourceCard: React.FC<{
  file: SourceFile;
  index: number;
  processProgress: number;
}> = ({file, index, processProgress}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const intro = spring({
    frame: frame - index * 12,
    fps,
    config: {damping: 17, stiffness: 130},
  });
  const pos = cardPositions[index];
  const pulse = interpolate(processProgress, [0, 0.35, 0.7, 1], [0, 1, 0.45, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        left: pos.x,
        top: pos.y,
        width: pos.w,
        opacity: intro,
        transform: `translateY(${(1 - intro) * 70}px)`,
        border: `1px solid rgba(69,213,255,${0.22 + pulse * 0.45})`,
        background: `linear-gradient(180deg, ${colors.panel}, ${colors.panel2})`,
        borderRadius: 8,
        boxShadow: `0 28px 90px rgba(0,0,0,0.35), 0 0 ${pulse * 40}px rgba(69,213,255,0.35)`,
        overflow: 'hidden',
      }}
    >
      <CardHeader title={file.name} subtitle={file.subtitle} />
      <div style={{padding: '22px 24px 28px'}}>
        {file.lines.map((line, lineIndex) => (
          <SourceLine
            key={`${file.name}-${lineIndex}`}
            text={line.text}
            kind={line.kind}
            index={lineIndex}
            processProgress={processProgress}
          />
        ))}
      </div>
    </div>
  );
};

const SourceLine: React.FC<{
  text: string;
  kind?: 'directive' | 'active' | 'inactive' | 'import';
  index: number;
  processProgress: number;
}> = ({text, kind, index, processProgress}) => {
  const inactiveOpacity = interpolate(processProgress, [0.35, 0.85], [1, 0.18], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const directiveOpacity = interpolate(processProgress, [0.62, 1], [1, 0.35], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const activeGlow = interpolate(processProgress, [0.2, 0.7], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const color =
    kind === 'directive'
      ? colors.amber
      : kind === 'import'
        ? colors.blue
        : kind === 'inactive'
          ? colors.red
          : kind === 'active'
            ? colors.green
            : colors.text;
  const opacity =
    kind === 'inactive'
      ? inactiveOpacity
      : kind === 'directive' || kind === 'import'
        ? directiveOpacity
        : 1;

  return (
    <div
      style={{
        display: 'flex',
        position: 'relative',
        fontFamily: '"SF Mono", Menlo, Consolas, monospace',
        fontSize: 20,
        lineHeight: '34px',
        color,
        opacity,
        textDecoration:
          kind === 'inactive' && processProgress > 0.62 ? 'line-through' : 'none',
        textDecorationThickness: 3,
      }}
    >
      {kind === 'active' && (
        <div
          style={{
            position: 'absolute',
            inset: '2px -10px',
            background: `rgba(114,241,168,${0.1 * activeGlow})`,
            border: `1px solid rgba(114,241,168,${0.35 * activeGlow})`,
            borderRadius: 8,
          }}
        />
      )}
      <span style={{width: 40, color: colors.muted, opacity: 0.72}}>{index + 1}</span>
      <span style={{position: 'relative', whiteSpace: 'pre'}}>{text}</span>
    </div>
  );
};

const MoonBitConsole: React.FC<{
  progress: number;
  processProgress: number;
  finalProgress: number;
}> = ({
  progress,
  processProgress,
  finalProgress,
}) => {
  const scan = interpolate(processProgress, [0, 1], [0, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const finalFade = interpolate(finalProgress, [0, 1], [1, 0.2], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 320,
        top: 704,
        width: 1280,
        opacity: progress * finalFade,
        transform: `translateY(${(1 - progress) * 42 + finalProgress * 34}px)`,
        border: `1px solid ${colors.border}`,
        background: 'rgba(8, 22, 27, 0.9)',
        borderRadius: 8,
        boxShadow: '0 22px 80px rgba(0,0,0,0.36)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          height: 56,
          padding: '14px 24px',
          borderBottom: `1px solid ${colors.border}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{fontSize: 22, color: colors.cyan, fontWeight: 760}}>
          MoonBit preprocessing code
        </div>
        <div style={{fontSize: 18, color: colors.green, fontWeight: 720}}>
          USE_TEXTURE = true
        </div>
      </div>
      <div style={{position: 'relative', padding: '18px 26px 22px'}}>
        <div
          style={{
            position: 'absolute',
            left: 22,
            right: 22,
            top: 22 + scan * 218,
            height: 34,
            background:
              'linear-gradient(90deg, transparent, rgba(69,213,255,0.24), transparent)',
            opacity: processProgress,
          }}
        />
        {moonbitLines.map((line, index) => (
          <div
            key={`${line}-${index}`}
            style={{
              position: 'relative',
              fontFamily: '"SF Mono", Menlo, Consolas, monospace',
              fontSize: 21,
              lineHeight: '31px',
              color:
                line.includes('USE_TEXTURE') || line.includes('preprocess')
                  ? colors.green
                  : line === ''
                    ? colors.muted
                    : colors.text,
              whiteSpace: 'pre',
            }}
          >
            {line === '' ? '\u00A0' : line}
          </div>
        ))}
      </div>
    </div>
  );
};

const Processor: React.FC<{frame: number; progress: number}> = ({frame, progress}) => {
  const opacity = interpolate(progress, [0, 0.18, 1], [0, 1, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const sweep = interpolate(frame, [timing.processStart, timing.outputStart], [-160, 160], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 802,
        top: 214,
        width: 316,
        height: 86,
        opacity,
        transform: `scale(${0.92 + progress * 0.08})`,
        border: `1px solid rgba(114,241,168,${0.28 + progress * 0.42})`,
        background: 'rgba(7, 24, 29, 0.92)',
        borderRadius: 8,
        overflow: 'hidden',
        boxShadow: `0 0 ${52 * progress}px rgba(114,241,168,0.34)`,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: sweep,
          top: 0,
          bottom: 0,
          width: 115,
          background:
            'linear-gradient(90deg, transparent, rgba(114,241,168,0.36), transparent)',
        }}
      />
      <div
        style={{
          position: 'relative',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
        }}
      >
        <div style={{fontSize: 26, fontWeight: 780}}>Preprocessor</div>
        <div style={{fontSize: 17, color: colors.muted, marginTop: 4}}>
          resolve imports + fold shader defs
        </div>
      </div>
    </div>
  );
};

const FlowLayer: React.FC<{progress: number; outputProgress: number}> = ({
  progress,
  outputProgress,
}) => {
  return (
    <div style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      {movingLines.map((line) => (
        <FlyingLine
          key={line.text}
          line={line}
          progress={progress}
          outputProgress={outputProgress}
        />
      ))}
      <Connector progress={progress} />
    </div>
  );
};

const FlyingLine: React.FC<{
  line: MovingLine;
  progress: number;
  outputProgress: number;
}> = ({line, progress, outputProgress}) => {
  const p = interpolate(progress, [0.18 + line.delay / 140, 0.58 + line.delay / 140], [0, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const opacity = interpolate(p, [0, 0.12, 0.82, 1], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const x = interpolate(p, [0, 1], [line.from.x, line.to.x], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const y = interpolate(p, [0, 1], [line.from.y, line.to.y], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const scale = interpolate(outputProgress, [0, 1], [1, 0.82], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        opacity,
        transform: `scale(${scale})`,
        transformOrigin: 'left center',
        fontFamily: '"SF Mono", Menlo, Consolas, monospace',
        fontSize: 22,
        lineHeight: '34px',
        color: line.color,
        background: 'rgba(8, 24, 29, 0.82)',
        border: `1px solid ${line.color}66`,
        borderRadius: 8,
        padding: '4px 12px',
        boxShadow: `0 0 28px ${line.color}55`,
        whiteSpace: 'pre',
      }}
    >
      {line.text}
    </div>
  );
};

const Connector: React.FC<{progress: number}> = ({progress}) => {
  const opacity = interpolate(progress, [0.08, 0.35, 0.95], [0, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const width = interpolate(progress, [0.1, 0.8], [0, 1250], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 335,
        top: 254,
        width,
        height: 4,
        opacity,
        borderRadius: 99,
        background:
          'linear-gradient(90deg, rgba(69,213,255,0.05), rgba(69,213,255,0.8), rgba(114,241,168,0.8), rgba(69,213,255,0.05))',
        boxShadow: '0 0 34px rgba(69,213,255,0.65)',
      }}
    />
  );
};

const OutputPanel: React.FC<{progress: number; finalProgress: number}> = ({
  progress,
  finalProgress,
}) => {
  const x = interpolate(progress, [0, 1], [1090, 900], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const y = interpolate(finalProgress, [0, 1], [300, 222], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const scale = interpolate(finalProgress, [0, 1], [0.88, 1.08], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const opacity = interpolate(progress, [0, 0.18, 1], [0, 0.45, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        width: 820,
        opacity,
        transform: `scale(${scale})`,
        transformOrigin: 'center top',
        border: `1px solid rgba(114,241,168,${0.32 + finalProgress * 0.45})`,
        background: `linear-gradient(180deg, ${colors.panel}, ${colors.panel2})`,
        borderRadius: 8,
        boxShadow: `0 28px 100px rgba(0,0,0,0.42), 0 0 ${finalProgress * 55}px rgba(114,241,168,0.32)`,
        overflow: 'hidden',
      }}
    >
      <CardHeader
        title="preprocessed sprite.wgsl"
        subtitle="ready for composer output"
      />
      <div style={{padding: '24px 28px 30px'}}>
        {outputLines.map((line, index) => (
          <OutputLine
            key={`${line}-${index}`}
            line={line}
            index={index}
            progress={progress}
          />
        ))}
      </div>
    </div>
  );
};

const OutputLine: React.FC<{line: string; index: number; progress: number}> = ({
  line,
  index,
  progress,
}) => {
  const lineIn = interpolate(progress, [0.3 + index * 0.035, 0.5 + index * 0.035], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        display: 'flex',
        fontFamily: '"SF Mono", Menlo, Consolas, monospace',
        fontSize: 22,
        lineHeight: '35px',
        color:
          line.includes('texture_2d') || line.includes('sample_base_color')
            ? colors.green
            : line.startsWith('@')
              ? colors.blue
              : line === ''
                ? colors.muted
                : colors.text,
        opacity: line === '' ? 0.55 : lineIn,
        transform: `translateX(${(1 - lineIn) * 18}px)`,
        whiteSpace: 'pre',
      }}
    >
      <span style={{width: 42, color: colors.muted, opacity: 0.72}}>
        {line === '' ? '' : index + 1}
      </span>
      <span>{line === '' ? '\u00A0' : line}</span>
    </div>
  );
};

const CardHeader: React.FC<{title: string; subtitle: string}> = ({
  title,
  subtitle,
}) => (
  <div
    style={{
      height: 74,
      padding: '15px 22px',
      borderBottom: `1px solid ${colors.border}`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
    }}
  >
    <div>
      <div style={{fontSize: 22, fontWeight: 760}}>{title}</div>
      <div style={{fontSize: 16, color: colors.muted, marginTop: 4}}>{subtitle}</div>
    </div>
    <div style={{display: 'flex', gap: 8}}>
      <Dot color="#ff6b7a" />
      <Dot color="#ffd166" />
      <Dot color="#72f1a8" />
    </div>
  </div>
);

const Dot: React.FC<{color: string}> = ({color}) => (
  <span
    style={{
      width: 12,
      height: 12,
      borderRadius: 999,
      background: color,
      display: 'block',
    }}
  />
);

const Footer: React.FC<{frame: number}> = ({frame}) => {
  const opacity = interpolate(frame, [338, 390], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        right: 92,
        bottom: 60,
        opacity,
        fontSize: 30,
        color: colors.text,
        fontWeight: 740,
      }}
    >
      Source variants in. Clean WGSL out.
    </div>
  );
};

const Grid: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      backgroundImage:
        'linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)',
      backgroundSize: '64px 64px',
      maskImage: 'linear-gradient(180deg, transparent, black 12%, black 80%, transparent)',
    }}
  />
);
