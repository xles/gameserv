require "cinch"

class GameState
  include Cinch::Plugin

  @@cmds = ["help", "list", "add", "remove", "update"]

  @@game_state = {}

  match(/roll$/, method: :help)
  match(/help roll$/, method: :help)
  match(/new campaign$/, method: :newCampaign)

  def help(m)
    m.reply 'Usage: !roll [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]'
    m.reply 'Usage: !roll add <dice roll> <name> ["<description>"]'
    m.reply 'Usage: !roll update <name> <dice roll>'
    m.reply 'Usage: !roll remove <name>'
    m.reply 'Usage: !roll list'
  end

  def newCampaign(m)
  	@@game_state["Game master"] = m.user.authname

  	m.reply JSON.generate(@@game_state)
  end
end
