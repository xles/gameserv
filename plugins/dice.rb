require 'cinch'

class Dice
  include Cinch::Plugin

  match /roll$/, method: :help
  match /roll help$/, method: :help
  match /help roll$/, method: :help
  match /roll (?:(?:(\d+)#)?(\d+))?d(\d+)(?:([+-])(\d+))?/, method: :roll

  def help(m)
    m.reply 'Usage: !roll [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]'
  end

  # [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]
  def roll(m, repeats, rolls, sides, offset_op, offset)
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


    fmt = config[:format] || "%s rolling ( %s ) = %d"
    m.reply fmt % [m.user.authname, m.message[6..-1], total], false
  end
end
