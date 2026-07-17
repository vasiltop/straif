export function is_new_world_record(
  previous_best_time_ms: number | null,
  submitted_time_ms: number,
  run_was_accepted: boolean
) {
  return (
    run_was_accepted &&
    (previous_best_time_ms === null ||
      submitted_time_ms < previous_best_time_ms)
  );
}

export function parse_world_record_cursor(value: string | undefined) {
  if (value === undefined) {
    return { success: true, cursor: null } as const;
  }

  if (!/^(0|[1-9]\d*)$/.test(value)) {
    return { success: false } as const;
  }

  const cursor = Number(value);
  if (!Number.isSafeInteger(cursor)) {
    return { success: false } as const;
  }

  return { success: true, cursor } as const;
}

export function world_record_lock_key(mode: string, map_name: string) {
  return `world-record:${mode}:${map_name}`;
}
