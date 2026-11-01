import React from 'react';
import {AbsoluteFill, Audio, Img, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, Phone, ramp, SCREEN, settle} from './layout';
import {cameraAt} from './camera';
import {EntranceMasks, FlyingPieces} from './Entrances';

type Caption = {from: number; to: number; title: React.ReactNode; detail: string; x: number; y: number; width: number; size?: number};

function StoryCaptions({frame, landscape}: {frame: number; landscape: boolean}) {
  const captions: Caption[] = [
    {from: 0, to: 166, title: <>Ein Tipp.<br/><span style={{color: C.accent}}>Von Freunden.</span></>, detail: 'Entdecke deinen nächsten Favoriten.', x: 160, y: 350, width: 830},
    {from: 250, to: 380, title: <>Entdecken.<br/><span style={{color: C.accent}}>Lieben.</span></>, detail: 'Deine Musik. Deine Bewertung.', x: 1050, y: 335, width: 740},
    {from: 385, to: 447, title: <>Der kommt<br/><span style={{color: C.accent}}>in den Plan.</span></>, detail: 'Samstag. 19 Uhr. RIAN.', x: 1050, y: 335, width: 770},
    {from: 505, to: 775, title: <>Dein Samstag.<br/><span style={{color: C.accent}}>Dein Takt.</span></>, detail: 'Filtern. Planen. Zusammen erleben.', x: 100, y: 375, width: 580, size: 83},
    {from: 1000, to: 1185, title: <>Plan steht.<br/><span style={{color: C.accent}}>Los geht’s.</span></>, detail: 'Deine Bühne. Direkt auf der Karte.', x: 1030, y: 355, width: 780},
    {from: 1200, to: 1460, title: <>Und nichts<br/><span style={{color: C.accent}}>verpassen.</span></>, detail: 'Festival-News. Direkt in der App.', x: 100, y: 355, width: 640, size: 86},
  ];
  return <>{captions.map((caption, index) => {
    const alpha = ramp(frame, caption.from, caption.from+10)*(1-ramp(frame, caption.to-10, caption.to));
    if (alpha === 0) return null;
    return <div key={index} style={{position: 'absolute', left: landscape ? caption.x : 62, top: landscape ? caption.y : 85, width: landscape ? caption.width : 956, textAlign: landscape ? 'left' : 'center', opacity: alpha, transform: `translateY(${16*(1-ramp(frame, caption.from, caption.from+18))}px)`}}>
      <div style={{fontSize: landscape ? caption.size ?? 102 : 84, fontWeight: 650, lineHeight: 1.06, letterSpacing: landscape ? -4.3 : -3.8}}>{caption.title}</div>
      <div style={{fontSize: landscape ? 29 : 28, lineHeight: 1.3, color: C.muted, marginTop: 24, letterSpacing: -.4}}>{caption.detail}</div>
    </div>;
  })}</>;
}

function Closing({frame, landscape}: {frame: number; landscape: boolean}) {
  const local = frame-1482;
  if (local < 0) return null;
  const p = settle(local, 0, 32);
  return <div style={{position: 'absolute', left: landscape ? 175 : 70, top: landscape ? 265 : 95, width: landscape ? 930 : 940, textAlign: landscape ? 'left' : 'center', opacity: ramp(local, 0, 25), transform: `translateY(${18*(1-p)}px)`}}>
    <Img src={staticFile('app-icon.png')} style={{width: 128, height: 128, display: 'block', margin: landscape ? '0 0 28px' : '0 auto 25px', transform: `translateX(${-700*(1-p)}px) rotate(${-12*(1-p)}deg)`}}/>
    <div style={{fontSize: landscape ? 102 : 91, lineHeight: 1.09, fontWeight: 650, letterSpacing: -4.6}}>Rudolstadt.<br/><span style={{color: C.accent}}>Dein Festivalplan.</span></div>
    <div style={{fontSize: 30, color: C.muted, marginTop: 30}}>Die inoffizielle App für dein iPhone.</div>
    <div style={{fontSize: 29, fontWeight: 550, marginTop: 35, opacity: ramp(local, 30, 50)}}>Im App Store erhältlich</div>
  </div>;
}

export function Demo() {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const landscape = width > height;
  const camera = cameraAt(frame, landscape);
  return <AbsoluteFill style={{overflow: 'hidden', background: C.paper, color: C.ink, fontFamily: '-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif', WebkitFontSmoothing: 'antialiased'}}>
    <Audio src={staticFile('soundtrack.wav')}/>
    <AbsoluteFill style={{clipPath: landscape ? undefined : 'inset(340px 0 0 0)'}}>
      <div style={{position: 'absolute', left: camera.x, top: camera.y, width: camera.width, height: camera.width*SCREEN.height/SCREEN.width, transform: `rotate(${camera.rotation}deg)`, transformOrigin: '50% 50%'}}>
        <Phone geometry={{x: 0, y: 0, width: camera.width}}>
          <OffthreadVideo src={staticFile('clips/story.mp4')} muted style={{width: '100%', height: '100%', objectFit: 'cover'}}/>
          <EntranceMasks frame={frame} width={camera.width}/>
        </Phone>
        <FlyingPieces frame={frame} width={camera.width} landscape={landscape}/>
      </div>
    </AbsoluteFill>
    <StoryCaptions frame={frame} landscape={landscape}/>
    <Closing frame={frame} landscape={landscape}/>
  </AbsoluteFill>;
}
