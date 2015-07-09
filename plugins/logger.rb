require "cinch"
require "wisper"

class Logger
  include Cinch::Plugin


  listen_to :connect,    :method => :setup
  listen_to :disconnect, :method => :cleanup
  listen_to :channel,    :method => :log_public_message
 
  def initialize(*args)
    super
    @date_format    = "%Y-%m-%d"
    @time_format    = "%H:%M:%S"
    @message_format = "[%{time}] <%{nick}> %{msg}"
    @action_format  = "[%{time}] * %{nick} %{msg}"
    @filename       = "%{campaign}_%{date}.log"
    @running        = {}
    @logfile        = {}
  end

  def start_logger(channel, title)
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    filename = @filename % [
      :campaign => slug, 
      :date => Time.now.utc.strftime(@date_format)
    ]
    @logfile[channel]      = File.open(filename,"a+")
    @logfile[channel].sync = true
    @running[channel]      = true
    @logfile[channel].puts '=== Campagin "%s" started on %s UTC. ===' % [
      title,
      Time.now.utc.strftime("#{@date_format} #{@time_format}")
    ]
    
  end

  def stop_logger(channel, title)
    @logfile[channel].puts '=== Campagin "%s" stopped on %s UTC. ===' % [
      title,
      Time.now.utc.strftime("#{@date_format} #{@time_format}")
    ]
    @logfile[channel].close
    @running[channel] = false
  end
 
  def setup
    bot.debug("Opened message logfile at #{@filename}")
  end
 
  def cleanup
    bot.debug("Closed message logfiles.")
  end
 
  def log_public_message(m)
    return unless @running[m.channel.name]
    return if m.message == "!campaign stop"
    time = Time.now.utc.strftime(@time_format)
    if m.action_message
      @logfile[m.channel.name].puts @action_format % [
        :time => time,
        :nick => m.user.name,
        :msg  => m.action_message
      ]
    else
      @logfile[m.channel.name].puts @message_format % [
        :time => time,
        :nick => m.user.name,
        :msg  => m.message
      ]
    end
  end
 
end
