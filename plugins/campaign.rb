require "cinch"
require "json"
require "wisper"

class Campaign
  include Cinch::Plugin
  include Wisper::Publisher

  @@cmds = ["help", "list", "add", "remove", "update"]

  @@game_state = {}

  match(/banana$/, method: :banana)
  match(/campaign$/, method: :help)
  match(/campaign echo\s.*$/, method: :echo_message)
  match(/help campagin$/, method: :help)
  match(/campaign start$/, method: :start_campaign)
  match(/campaign stop$/, method: :stop_campaign)
  match(/campaign party\s(.*)$/, method: :set_party)
  match(/campaign load\s(.*)$/, method: :load_campagin)
  match(/campaign new(?:\s(.*))?$/, method: :new_campaign)

  def help(m)
    m.reply 'Usage: !roll [[<repeats>#]<rolls>]d<sides>[<+/-><offset>]'
    m.reply 'Usage: !roll add <dice roll> <name> ["<description>"]'
    m.reply 'Usage: !roll update <name> <dice roll>'
    m.reply 'Usage: !roll remove <name>'
    m.reply 'Usage: !roll list'
  end

  def start_campaign(m)
    return unless m.target.instance_of? Cinch::Channel
    return unless @@game_state["title"]
    broadcast(:start_logger, m.channel.name, @@game_state["title"])
  end

  def stop_campaign(m)
    return unless m.target.instance_of? Cinch::Channel
    broadcast(:stop_logger, m.channel.name, @@game_state["title"])
  end

  def echo_message(m)
    m.user.send m.message
  end

  def new_campaign(m, title)
  	@@game_state["Game master"] = m.user.authname
  	@@game_state["title"] = title || "Untitled"

  	m.reply JSON.generate(@@game_state)
  end

  def load_campagin(m, title)
    m.reply  m.channel.name
    sth = $dbh.prepare(%|SELECT "game_state"
      FROM "game_states"
        WHERE "channel" ILIKE ?
        AND "game_state"->>'title' ILIKE ?|)
    sth.bind_param 1, m.channel.name
    sth.bind_param 2, title
    sth.execute
  end

  def set_party(m, members)
    members = members.split(/\s/)
    @@game_state["party"] = members
    
    update_game_state(m)
    m.reply JSON.generate(@@game_state)
  end

  def update_game_state(m)
    sth = $dbh.prepare(%|SELECT COUNT(*) 
      FROM "game_states" 
        WHERE "game_state"->>'Game master' ILIKE ?
        AND "game_state"->>'title' ILIKE ?
        AND "channel" ILIKE ?|)
    sth.bind_param 1, m.user.authname
    sth.bind_param 2, @@game_state["title"]
    sth.bind_param 3, m.channel.name
    sth.execute

    if sth.fetch[0] < 1
      sth = $dbh.prepare('INSERT into "game_states"
        ("game_state", "channel", "secondary_channel")
        VALUES (?, ?, ?)')
      sth.bind_param 1, JSON.pretty_generate(@@game_state)
      sth.bind_param 2, m.channel.name
      sth.bind_param 3, m.channel.name
      sth.execute
    end

    sth = $dbh.prepare(%|UPDATE "game_states"
        SET "game_state" = ?
        WHERE "game_state"->>'Game master' ILIKE ?
        AND "game_state"->>'title' ILIKE ?
        AND "channel" ILIKE ?|)
    sth.bind_param 1, JSON.pretty_generate(@@game_state)
    sth.bind_param 2, @@game_state["Game master"]
    sth.bind_param 3, @@game_state["title"]
    sth.bind_param 4, m.channel.name
    sth.execute
  end
end
