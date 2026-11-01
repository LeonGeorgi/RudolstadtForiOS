import {interpolate} from 'remotion';
import {ease} from './layout';

export type Camera = {x: number; y: number; width: number; rotation: number};
type Keyframe = Camera & {at: number};

const landscape: Keyframe[] = [
  {at: 0, x: 1080, y: 390, width: 470, rotation: -6},
  {at: 42, x: 1110, y: 54, width: 442, rotation: 0},
  {at: 166, x: 1110, y: 54, width: 442, rotation: 0},
  {at: 260, x: 230, y: -20, width: 620, rotation: 0},
  {at: 308, x: 190, y: -210, width: 760, rotation: 0},
  {at: 370, x: 190, y: -210, width: 760, rotation: 0},
  {at: 395, x: 205, y: -390, width: 690, rotation: 0},
  {at: 460, x: 205, y: -390, width: 690, rotation: 0},
  {at: 510, x: 750, y: 55, width: 440, rotation: 0},
  {at: 780, x: 750, y: 55, width: 440, rotation: 0},
  {at: 820, x: 650, y: 35, width: 630, rotation: 0},
  {at: 875, x: 650, y: 35, width: 630, rotation: 0},
  {at: 1010, x: 220, y: 30, width: 630, rotation: 0},
  {at: 1170, x: 220, y: 30, width: 630, rotation: 0},
  {at: 1240, x: 850, y: 40, width: 580, rotation: 0},
  {at: 1350, x: 850, y: 40, width: 580, rotation: 0},
  {at: 1400, x: 825, y: 10, width: 640, rotation: 0},
  {at: 1450, x: 825, y: 10, width: 640, rotation: 0},
  {at: 1512, x: 1220, y: 75, width: 420, rotation: 0},
  {at: 1662, x: 1220, y: 75, width: 420, rotation: 0},
];
const portrait: Keyframe[] = [
  {at: 0, x: 185, y: 930, width: 710, rotation: -5},
  {at: 42, x: 210, y: 395, width: 660, rotation: 0},
  {at: 166, x: 210, y: 395, width: 660, rotation: 0},
  {at: 260, x: 115, y: 365, width: 850, rotation: 0},
  {at: 308, x: 30, y: 250, width: 1020, rotation: 0},
  {at: 370, x: 30, y: 250, width: 1020, rotation: 0},
  {at: 395, x: 75, y: -165, width: 930, rotation: 0},
  {at: 460, x: 75, y: -165, width: 930, rotation: 0},
  {at: 510, x: 210, y: 395, width: 660, rotation: 0},
  {at: 780, x: 210, y: 395, width: 660, rotation: 0},
  {at: 820, x: 80, y: 300, width: 920, rotation: 0},
  {at: 875, x: 80, y: 300, width: 920, rotation: 0},
  {at: 1010, x: 95, y: 370, width: 890, rotation: 0},
  {at: 1170, x: 95, y: 370, width: 890, rotation: 0},
  {at: 1240, x: 150, y: 385, width: 780, rotation: 0},
  {at: 1350, x: 150, y: 385, width: 780, rotation: 0},
  {at: 1400, x: 95, y: 350, width: 890, rotation: 0},
  {at: 1450, x: 95, y: 350, width: 890, rotation: 0},
  {at: 1512, x: 325, y: 790, width: 430, rotation: 0},
  {at: 1662, x: 325, y: 790, width: 430, rotation: 0},
];

export function cameraAt(frame: number, isLandscape: boolean): Camera {
  const keys = isLandscape ? landscape : portrait;
  const times = keys.map(k => k.at);
  const value = (name: keyof Camera) => interpolate(frame, times, keys.map(k => k[name]), {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease,
  });
  return {x: value('x'), y: value('y'), width: value('width'), rotation: value('rotation')};
}
