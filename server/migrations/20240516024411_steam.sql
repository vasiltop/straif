-- Add migration script here
ALTER TABLE placement_longjump
ADD username TEXT NOT NULL;

ALTER TABLE placement_bhop
ADD username TEXT NOT NULL;


