require "cinch"
require "dbi"
Dir["./plugins/*.rb"].each {|file| require file }

$dbh = DBI.connect("DBI:Pg:lhl")

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.quakenet.org"
    c.channels = ["#gameservdebug"]
    c.nick = "GameServ|Debug"
    c.plugins.plugins = [
      Dice,
      Campaign,
      Logger
    ]
  end

  on :message, "hello" do |m|
    m.reply "Hello, #{m.user.nick}"
  end
end

Wisper.subscribe(Logger.new(bot))

bot.start
