import React from 'react';
import {Composition} from 'remotion';
import {PreprocessDemo} from './PreprocessDemo';

export const Root: React.FC = () => {
  return (
    <Composition
      id="PreprocessDemo"
      component={PreprocessDemo}
      durationInFrames={420}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
