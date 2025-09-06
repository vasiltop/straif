import db from '../src/db/index.ts';
import { runs } from '../src/db/schema.ts';

const MODE_MAP_REF = {
  target: [
    'Tutorial',
    'map_rooftops',
    'map_streets',
    'map_flow',
    'map_structure',
    'map_graybox',
    'map_graybox2',
    'map_subway',
    'map_rooftops2',
  ],
  bhop: [
    'Tutorial',
    'map_rooftops',
    'map_streets',
    'map_flow',
    'map_line',
    'map_rookie',
    'map_dawn',
    'map_structure',
    'map_graybox',
    'map_graybox2',
    'map_subway',
    'map_rooftops2',
    'map_slope',
    'map_taurus'
  ]
}

const RUNS_PER_MAP = 55;

function gen_string(length) {
  const characters =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let res = '';

  for (let i = 0; i < length; i++) {
    res += characters[Math.floor(Math.random() * characters.length)];
  }

  return res;
}

async function populate() {
  for (const mode of Object.keys(MODE_MAP_REF)) {
    const mode_maps = MODE_MAP_REF[mode];
    console.log(mode)
    for (const map_name of mode_maps) {
      for (let i = 0; i < RUNS_PER_MAP; ++i) {
        console.log(`Inserting run ${i} into map ${map_name} for mode ${mode}.`);
        await db.insert(runs).values({
          steam_id: gen_string(10),
          map_name,
          recording: '',
          map_name,
          time_ms: Math.floor((Math.random() * 10 + 10) * 1000),
          username: gen_string(10),
          mode: mode,
        });
      }
    }
  }
}

populate();
