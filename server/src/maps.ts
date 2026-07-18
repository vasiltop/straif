import { run_mode } from './db/schema';
import mapData from '../../maps.json';

export type RunMode = (typeof run_mode.enumValues)[number];

export type Map = {
  name: string;
  tier: number;
  modes: string[];
  medals_target?: number[];
  medals_bhop?: number[];
};

export function get_maps_of_mode(mode: RunMode): Map[] {
  return mapData.maps.filter((m) => {
    return m.modes.includes(mode);
  });
}
