-- Add migration script here
CREATE TABLE IF NOT EXISTS "user" (
    id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(32) NOT NULL,
    password BYTEA NOT NULL,
    admin BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS "map" (
    id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "placement_bhop" (
    user_id UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    map_id UUID NOT NULL REFERENCES "map"(id) ON DELETE CASCADE,
    run BYTEA NOT NULL,
    time_ms INT NOT NULL,
    PRIMARY KEY (user_id, map_id)
);

CREATE TABLE IF NOT EXISTS "placement_longjump" (
    user_id UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    length SMALLINT NOT NULL,
    PRIMARY KEY (user_id)
);

CREATE INDEX bhop_time ON placement_bhop (time_ms ASC);
CREATE INDEX longjump_length ON placement_longjump (length DESC);

CREATE OR REPLACE VIEW bhop_leaderboard AS
    SELECT username, run, time_ms, map_id FROM placement_bhop
    INNER JOIN "user"
    ON "user".id = placement_bhop.user_id
    ORDER BY time_ms ASC;

CREATE OR REPLACE VIEW longjump_leaderboard AS
    SELECT username, length FROM placement_longjump
    INNER JOIN "user"
    ON "user".id = placement_longjump.user_id
    ORDER BY length DESC;