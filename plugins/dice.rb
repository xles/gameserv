require 'cinch'

class Dice
  include Cinch::Plugin

  @@roll_re = /(?:(?:(\d+)#)?(\d+))?d(\d+)(?:([+-])(\d+))?/i
  @@cmds = ["help", "list", "add"]

  match /roll$/, method: :help
  match /help roll$/, method: :help
  match /roll help$/, method: :help
  match /roll list$/, method: :list
  #match /roll add (\S+)\s+?:(\w+)\s+?:(\w+))/, method: :add
  match /roll add (\S+)\s+(\w+)(?:\s+)?(?:"(.+)")?$/, method: :add
  match /roll (?:(\w+))$/, method: :saved
  match Regexp.new('roll ' + @@roll_re.to_s), method: :direct

  def help(m)
    m.reply 'Usage: !roll [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]'
  end

  def add(m, dice_roll, name, description)
    if !dice_roll.match @@roll_re
      m.reply "Invalid dice roll."
      return
    end
    
    if !description
      description = name
    end
    sth = $dbh.prepare('INSERT into "saved_rolls"
      ("user", "description", "dice_roll", "name")
      VALUES (?, ?, ?, ?)')
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, description
    sth.bind_param 3, dice_roll
    sth.bind_param 4, name
    sth.execute

    m.reply '%s saved as "%s"' % [dice_roll, name]
  end

  def list(m)
    sth = $dbh.prepare('SELECT "description", "dice_roll", "name"
      FROM saved_rolls 
        WHERE "user" ILIKE ?')
    sth.bind_param 1, m.user.authname
    sth.execute

    rolls = sth.fetch_all

    if rolls.length == 0
      m.reply "You don't have any saved rolls.", true
    else
      m.reply "Your saved rolls are:", true
    end

    name_len = roll_len = desc_len = 0

    rolls.each do |row|
      if row["name"].length > name_len 
        name_len = row["name"].length
      end
      if row["dice_roll"].length > roll_len 
        roll_len = row["dice_roll"].length
      end
#      if row["description"].length > desc_len 
#        desc_len = row["description"].length
#      end
    end

    fmt = "%-" + name_len.to_s + "s | %" + roll_len.to_s + "s | %s"

    rolls.each do |row|
      m.reply fmt % [row["name"], row["dice_roll"], row["description"]]
    end
  end

  def saved(m, roll_name)
    if roll_name.match @@roll_re then return end
    if @@cmds.include? roll_name then return end
    sth = $dbh.prepare('SELECT "description", "dice_roll" 
      FROM saved_rolls 
        WHERE "user" ILIKE ? 
        AND "name" ILIKE ?')
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, roll_name
    sth.execute

    row = sth.fetch_all

    if row.length == 0
      m.reply "Unknown roll, use `!roll list` to see your saved rolls."
    else
      row = row[0]
      fmt = '%s rolling "%s" ( %s ) = %d'
      parts = row["dice_roll"].match @@roll_re
      total = roll(parts[1], parts[2], parts[3], parts[4], parts[5])
      m.reply fmt % [m.user.authname, row["description"], row["dice_roll"], total]
    end
    sth.finish
  end


  def direct(m, repeats, rolls, sides, offset_op, offset)
    total = roll(repeats, rolls, sides, offset_op, offset)
    fmt = config[:format] || "%s rolling ( %s ) = %d"
    m.reply fmt % [m.user.authname, m.message[6..-1], total], false
  end

  # [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]
  def roll(repeats, rolls, sides, offset_op, offset)
    repeats = repeats.to_i
    repeats = 1 if repeats < 1
    rolls   = rolls.to_i
    rolls   = 1 if rolls < 1

    total = 0

    repeats.times do
      rolls.times do
        total += rand(sides.to_i) + 1
      end
      if offset_op
        total = total.send(offset_op, offset.to_i)
      end
    end

    return total
  end
end
