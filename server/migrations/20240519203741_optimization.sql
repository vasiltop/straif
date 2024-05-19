-- Add migration script here
DROP VIEW bhop_leaderboard;
DROP VIEW longjump_leaderboard;

CREATE OR REPLACE VIEW bhop_leaderboard AS
    SELECT run, user_id, username, time_ms FROM placement_bhop
    ORDER BY time_ms ASC;

CREATE OR REPLACE VIEW longjump_leaderboard AS
    SELECT jump, user_id, username, length FROM placement_longjump
    ORDER BY length DESC;
