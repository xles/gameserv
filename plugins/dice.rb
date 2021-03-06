require "cinch"

class Dice
  include Cinch::Plugin

  @@roll_re = /(?:(?:(\d+)#)?(\d+))?d(\d+)(?:([+-])(\d+))?/i
  @@cmds = ["help", "list", "add", "remove", "update"]

  match(/roll$/, method: :help)
  match(/help roll$/, method: :help)
  match(/roll help$/, method: :help)
  match(/roll list$/, method: :list)
  match(/list rolls$/, method: :list)
  match(/roll remove (\w+)(?:\s+)?$/, method: :destroy)
  match(/remove roll (\w+)(?:\s+)?$/, method: :destroy)
  match(/roll update (\w+)\s+(\S+)(?:\s+)?$/, method: :update)
  match(/update roll (\w+)\s+(\S+)(?:\s+)?$/, method: :update)
  match(/roll add (\S+)\s+(\w+)(?:\s+)?(?:"(.+)")?$/, method: :add)
  match(/add roll (\S+)\s+(\w+)(?:\s+)?(?:"(.+)")?$/, method: :add)
  match(/roll (\w+)(?:\s(.*))?$/, method: :saved)
  match Regexp.new('roll ' + @@roll_re.to_s), method: :direct

  def help(m)
    m.reply 'Usage: !roll [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]'
    m.reply 'Usage: !roll add <dice roll> <name> ["<description>"]'
    m.reply 'Usage: !roll update <name> <dice roll>'
    m.reply 'Usage: !roll remove <name>'
    m.reply 'Usage: !roll list'
  end

  def add(m, dice_roll, name, description)
    unless dice_roll.match @@roll_re
      m.reply "Invalid dice roll."
      return
    end
    
    unless description
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

    m.reply "%s saved as '%s'" % [dice_roll, name]
  end

  def list(m)
    sth = $dbh.prepare('SELECT "description", "dice_roll", "name"
      FROM saved_rolls 
        WHERE "user" ILIKE ?')
    sth.bind_param 1, m.user.authname
    sth.execute

    rolls = sth.fetch_all

    if rolls.length == 0
      m.user.send "You don't have any saved rolls."
      return
    else
      m.user.send "Your saved rolls are:"
    end

    name_len = 4
    roll_len = 9
    desc_len = 11

    rolls.each do |row|
      if row["name"].length > name_len 
        name_len = row["name"].length
      end
      if row["dice_roll"].length > roll_len 
        roll_len = row["dice_roll"].length
      end
      if row["description"].length > desc_len 
        desc_len = row["description"].length
      end
    end

    tot_len = name_len + roll_len + desc_len + 6;

    fmt = "%-" + name_len.to_s + "s | %" + roll_len.to_s + "s | %s"
    fmt2 = "%-" + name_len.to_s + "s|%" + roll_len.to_s + "s|%s"

    m.user.send fmt % ["name", "dice roll", "description"]
    
    m.user.send fmt2 % ["-" * (name_len+1), "-" * (roll_len+2), "-" * (desc_len+1)]

    rolls.each do |row|
      m.user.send fmt % [row["name"], row["dice_roll"], row["description"]]
    end
    m.user.send "%s" % "-" * tot_len
  end

  def update(m, name, dice_roll)
    unless dice_roll.match @@roll_re
      m.reply "Invalid dice roll."
      return
    end

    sth = $dbh.prepare('SELECT COUNT(*) 
      FROM "saved_rolls" 
        WHERE "user" = ?
        AND "name" = ?')
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, name
    sth.execute

    if sth.fetch[0] < 1
      m.reply "Unable to update: No such roll '%s'" % name
      return
    end

    sth = $dbh.prepare('UPDATE "saved_rolls"
        SET "dice_roll" = ?
        WHERE "user" = ?
        AND "name" = ?')
    sth.bind_param 1, dice_roll
    sth.bind_param 2, m.user.authname
    sth.bind_param 3, name
    sth.execute

    m.reply '%s saved as "%s"' % [dice_roll, name]
  end

  def destroy(m, name)
    sth = $dbh.prepare('SELECT COUNT(*) 
      FROM "saved_rolls" 
        WHERE "user" = ?
        AND "name" = ?')
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, name
    sth.execute

    if sth.fetch[0] < 1
      m.reply "Unable to remove: No such roll '%s'" % name
      return
    end

    sth = $dbh.prepare('DELETE FROM "saved_rolls"
        WHERE "user" = ?
        AND "name" = ?')
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, name
    sth.execute

    m.reply "'%s' successfully removed." % [name]
  end

  def saved(m, roll_name, offset)
    return if roll_name.match @@roll_re
    return if @@cmds.include? roll_name
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
      parts = row["dice_roll"].match Regexp.new(@@roll_re.to_s + '(?:\s(.*))?')
      if offset
        int_offset = (parts[5].to_i + offset.to_i)
        fmt = '%{user} rolling "%{name}" ( %{roll} ) %{offset} = %{total}'
      else
        int_offset = parts[5]
        fmt = '%{user} rolling "%{name}" ( %{roll} ) = %{total}'
      end
      total = roll(parts[1], parts[2], parts[3], parts[4], int_offset)
      m.reply fmt % [
        :user   => m.user.authname,
        :name   => row["description"],
        :roll   => row["dice_roll"],
        :offset => offset,
        :total  => total
      ]
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
