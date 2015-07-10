class Migration_2015_07_10_initial

  def up
    $dbh.do(
      'CREATE TABLE saved_rolls (
          "id" SERIAL,
          "user" character varying,
          "dice_roll" text,
          "name" text,
          "description" text
      );'
    )
    $dbh.do(
      'CREATE TABLE game_states (
          "id" SERIAL,
          "game_state" json,
          "channel" character varying,
          "secondary_channel" text
      );'
    )
  end

  def down
  end

end
