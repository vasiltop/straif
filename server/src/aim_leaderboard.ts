export const AIM_SCENARIOS = ['gridshot', 'flick', 'tracking'] as const;

export type AimScenario = (typeof AIM_SCENARIOS)[number];

export function parseAimScenario(value: string): AimScenario | null {
  return AIM_SCENARIOS.includes(value as AimScenario)
    ? (value as AimScenario)
    : null;
}
