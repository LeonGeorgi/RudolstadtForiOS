import React, {CSSProperties, ReactNode, useId} from 'react';
import {Easing, interpolate, spring} from 'remotion';
import contours from './phone-contours.json';

export const C = {paper: '#faf9f7', ink: '#1d1d1f', muted: '#747277', accent: '#8d348f'};
export const SCREEN = {width: 1206, height: 2622};
export const ease = Easing.bezier(0.22, 0.7, 0.12, 1);
export const ramp = (f: number, from: number, to: number) => interpolate(f, [from, to], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease});
export const settle = (f: number, delay = 0, duration = 58) => spring({frame: Math.max(0, f - delay), fps: 60, durationInFrames: duration, config: {damping: 25, stiffness: 140, mass: 1}});
export function Phone({children, style, dark = false, island = false, geometry}: {children: ReactNode; style?: CSSProperties; dark?: boolean; island?: boolean; geometry: {x: number; y: number; width: number}}) {
  const phone = {...geometry, height: geometry.width * SCREEN.height / SCREEN.width};
  const clipId = `display-${useId().replace(/:/g, '')}`;
  const s = phone.width / 670;
  const sourceScale = phone.width / SCREEN.width;
  return <div style={{position: 'absolute', boxSizing: 'border-box', left: phone.x - 11*s, top: phone.y - 11*s, width: phone.width + 22*s, height: phone.height + 22*s, filter: 'drop-shadow(0 20px 25px rgba(20,18,25,.13))', ...style}}>
    <svg width="100%" height="100%" viewBox={`0 0 692 ${670 * SCREEN.height / SCREEN.width + 22}`} style={{position: 'absolute', inset: 0}}>
      <defs><clipPath id={clipId} clipPathUnits="objectBoundingBox"><path d={contours.display}/></clipPath></defs>
      <path d={contours.outer} fill="#29292b" stroke="#858487" strokeWidth="2"/>
    </svg>
    <div style={{position: 'absolute', left: 11*s, top: 11*s, width: phone.width, height: phone.height, overflow: 'hidden', clipPath: `url(#${clipId})`, background: dark ? '#000' : '#fff'}}>{children}</div>
    {island && <div style={{position: 'absolute', width: 376*sourceScale, height: 110*sourceScale, top: 11*s+42*sourceScale, left: '50%', transform: 'translateX(-50%)', borderRadius: 55*sourceScale, background: '#050505'}}/>}
  </div>;
}

