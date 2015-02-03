require 'fluent/mixin/config_placeholders'

class SyslogOutput < Fluent::Output
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('syslog', self)

  # This method is called before starting.

  config_param :remote_syslog, :string, :default => ""
  config_param :port, :integer, :default => 25
  config_param :hostname, :string, :default => ""
  config_param :remove_tag_prefix, :string, :default => nil
  config_param :tag_key, :string, :default => nil
  config_param :proto, :default => 'udp' do |val|
    f = ['tcp', 'udp'].include? val
    raise ConfigError, "Unsupported protocol '#{val}'" unless f
    f
  end
  config_param :facility, :string, :default => 'user'
  config_param :severity, :string, :default => 'debug'
  config_param :use_record, :string, :default => nil


  def initialize
    super
    require 'socket'
    require 'syslog_protocol'
  end

  def configure(conf)
    super
    if conf['proto'] == 'udp'
      @socket = UDPSocket.new
    end
    @packet = SyslogProtocol::Packet.new
    if remove_tag_prefix = conf['remove_tag_prefix']
        @remove_tag_prefix = Regexp.new('^' + Regexp.escape(remove_tag_prefix))
    end
    @facilty = conf['facility']
    @severity = conf['severity']
    @use_record = conf['use_record']
    @proto = conf['proto']
    @use_record = conf['use_record']
  end

  # This method is called when starting.
  def start
  end

  # This method is called when shutting down.
  def shutdown
  end

  # This method is called when an event reaches Fluentd.
  # 'es' is a Fluent::EventStream object that includes multiple events.
  # You can use 'es.each {|time,record| ... }' to retrieve events.
  # 'chain' is an object that manages transactions. Call 'chain.next' at
  # appropriate points and rollback if it raises an exception.
  def emit(tag, es, chain)
    chain.next
    es.each {|time,record|
      @packet.hostname = hostname
      if @use_use_record
        record['facility'] |= @facilty
        record['severity'] |= @severity
        @packet.facility = record['facility']
        @packet.severity = record['severity']
      else
        @packet.facility = @facilty
        @packet.severity = @severity
      end

      @packet.tag      = if tag_key 
                            record[tag_key][0..31].gsub(/[\[\]]/,'') # tag is trimmed to 32 chars for syslog_protocol gem compatibility
                         else
                            tag[0..31] # tag is trimmed to 32 chars for syslog_protocol gem compatibility
                         end
      packet = @packet.dup
      packet.content = record['message']
      if @proto == 'udp'
        @socket.send(packet.assemble, 0, @remote_syslog, @port)
      else
        sock = TCPSocket.new(@remote_syslog, @port)
        sock.write packet.assemble + "\n"
        sock.flush
      end
	}
  end
end

class Time
  def timezone(timezone = 'UTC')
    old = ENV['TZ']
    utc = self.dup.utc
    ENV['TZ'] = timezone
    output = utc.localtime
    ENV['TZ'] = old
    output
  end
end