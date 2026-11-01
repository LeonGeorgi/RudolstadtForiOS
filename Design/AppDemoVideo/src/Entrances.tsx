import React from 'react';
import {Img, staticFile} from 'remotion';
import {ramp, SCREEN, settle} from './layout';

type Piece = {x: number; y: number; width: number; height: number};
const photos: Piece[] = [
  {x: 96, y: 1138, width: 608, height: 532},
  {x: 740, y: 1138, width: 418, height: 532},
];
const concerts: Piece[] = [
  {x: 630, y: 921, width: 210, height: 174},
  {x: 405, y: 1281, width: 210, height: 264},
  {x: 630, y: 1281, width: 210, height: 174},
  {x: 855, y: 1281, width: 210, height: 174},
  {x: 855, y: 1641, width: 210, height: 174},
  {x: 405, y: 1821, width: 210, height: 264},
];

function piecesAt(frame: number) {
  if (frame < 66) return {pieces: photos, source: 'story-friends', local: frame, grid: false};
  if (frame >= 520 && frame < 604) return {pieces: concerts, source: 'story-saturday', local: frame - 520, grid: true};
  return undefined;
}

export function EntranceMasks({frame, width}: {frame: number; width: number}) {
  const entrance = piecesAt(frame);
  if (!entrance) return null;
  const s = width / SCREEN.width;
  const opacity = 1 - ramp(entrance.local, entrance.grid ? 65 : 52, entrance.grid ? 78 : 62);
  return <>{entrance.pieces.map((r, index) => <div key={index} style={{position: 'absolute', left: r.x*s, top: r.y*s, width: r.width*s, height: r.height*s, overflow: 'hidden', background: entrance.grid ? '#fff' : '#f2f2f7', borderRadius: (entrance.grid ? 8 : 14)*s, opacity}}>
    {entrance.grid && Array.from({length: 20}, (_, i) => 729+i*90-r.y).filter(y => y>0 && y<r.height).map(y => <div key={y} style={{position: 'absolute', top: y*s, width: '100%', height: s, background: '#dddde0'}}/>)}
  </div>)}</>;
}

export function FlyingPieces({frame, width, landscape}: {frame: number; width: number; landscape: boolean}) {
  const entrance = piecesAt(frame);
  if (!entrance) return null;
  const s = width / SCREEN.width;
  const tail = 1-ramp(entrance.local, entrance.grid ? 65 : 52, entrance.grid ? 78 : 62);
  return <>{entrance.pieces.map((r, i) => {
    const delay = i * (entrance.grid ? 5 : 8);
    const p = settle(entrance.local, delay, 42);
    const side = landscape ? 1 : i%2 ? 1 : -1;
    return <div key={i} style={{position: 'absolute', left: r.x*s, top: r.y*s, width: r.width*s, height: r.height*s, overflow: 'hidden', borderRadius: (entrance.grid ? 8 : 14)*s, opacity: ramp(entrance.local, delay, delay+8)*tail, transform: `translate(${side*2300*(1-p)}px,${(i%2 ? 230 : -180)*(1-p)}px) rotate(${side*5*(1-p)}deg)`, boxShadow: `0 ${18*(1-p)}px ${24*(1-p)}px rgba(0,0,0,${.14*(1-p)})`}}>
      <Img src={staticFile(`screens/${entrance.source}.png`)} style={{position: 'absolute', width: SCREEN.width*s, height: SCREEN.height*s, maxWidth: 'none', left: -r.x*s, top: -r.y*s}}/>
    </div>;
  })}</>;
}
