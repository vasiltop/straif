import map_data from '../../maps.json';
import { run_mode } from './db/schema';

export type RunMode = (typeof run_mode.enumValues)[number];

export type Map = {
  name: string;
  tier: number;
  modes: string[];
  medals_target: string[] | undefined;
  medals_bhop: string[] | undefined;
};

export function get_maps(): Map[] {
  return map_data.maps;
}

export function get_maps_of_mode(mode: RunMode): Map[] {
  return get_maps().filter((m) => {
    return m.modes.includes(mode);
  });
}
