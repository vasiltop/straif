-- Add migration script here
DROP VIEW bhop_leaderboard;
DROP VIEW longjump_leaderboard;
DROP TABLE placement_bhop;
DROP TABLE placement_longjump;

CREATE TABLE IF NOT EXISTS "placement_bhop" (
    user_id BIGINT NOT NULL,
    map_id UUID NOT NULL REFERENCES "map"(id) ON DELETE CASCADE,
    run BYTEA NOT NULL,
    time_ms INT NOT NULL,
    PRIMARY KEY (user_id, map_id)
);

CREATE TABLE IF NOT EXISTS "placement_longjump" (
    user_id BIGINT NOT NULL,
    length SMALLINT NOT NULL,
    PRIMARY KEY (user_id)
);


CREATE OR REPLACE VIEW bhop_leaderboard AS
    SELECT user_id, run, time_ms, map_id FROM placement_bhop
    ORDER BY time_ms ASC;

CREATE OR REPLACE VIEW longjump_leaderboard AS
    SELECT user_id, length FROM placement_longjump
    ORDER BY length DESC;



