import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {Demo} from './Demo';

registerRoot(() => <>
  <Composition id="RudolstadtPortrait" component={Demo} width={1080} height={1920} fps={60} durationInFrames={1662}/>
  <Composition id="RudolstadtLandscape" component={Demo} width={1920} height={1080} fps={60} durationInFrames={1662}/>
</>);
