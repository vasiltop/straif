-- Add migration script here
ALTER TABLE placement_longjump ADD COLUMN jump BYTEA NOT NULL;
