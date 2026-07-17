import { randomUUID } from 'node:crypto';

export type WorldRecordAnnouncement = {
  id: string;
  map_name: string;
  mode: string;
  steam_id: string;
  username: string;
  time_ms: number;
  created_at: string;
};

type WorldRecordInput = Omit<WorldRecordAnnouncement, 'id' | 'created_at'>;

export class RecentWorldRecords {
  private records: Array<{
    announcement: WorldRecordAnnouncement;
    expires_at: number;
  }> = [];

  constructor(private readonly ttl_ms = 60_000) {}

  publish(input: WorldRecordInput, now = Date.now()) {
    const announcement: WorldRecordAnnouncement = {
      ...input,
      id: randomUUID(),
      created_at: new Date(now).toISOString(),
    };
    this.records.push({
      announcement,
      expires_at: now + this.ttl_ms,
    });
    return announcement;
  }

  list(now = Date.now()) {
    this.records = this.records.filter((record) => record.expires_at > now);
    return this.records.map((record) => record.announcement);
  }
}

export const recent_world_records = new RecentWorldRecords();

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

export function world_record_lock_key(mode: string, map_name: string) {
  return `world-record:${mode}:${map_name}`;
}
