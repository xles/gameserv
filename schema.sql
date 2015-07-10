CREATE TABLE saved_rolls (
    "id" SERIAL,
    "user" character varying,
    "dice_roll" text,
    "name" text,
    "description" text
);
CREATE TABLE game_states (
    "id" SERIAL,
    "game_state" json,
    "channel" character varying,
    "secondary_channel" text
);
