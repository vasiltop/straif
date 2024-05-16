-- Add migration script here

CREATE TABLE IF NOT EXISTS steam_nickname (
    user_id BIGINT NOT NULL,
    username TEXT NOT NULL,
    PRIMARY KEY (user_id, username)
);
