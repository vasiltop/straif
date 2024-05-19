-- Add migration script here
DROP VIEW bhop_leaderboard;

CREATE OR REPLACE VIEW bhop_leaderboard AS
    SELECT run, map_id FROM placement_bhop
    ORDER BY time_ms ASC;


