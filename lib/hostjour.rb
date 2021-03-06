$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'rubygems'
require 'ghost'
require 'dnssd'

module Hostjour
  Host = Struct.new(:hostname, :ip, :identifier)
  
  VERSION = '0.0.1'
  SERVICE = "_hostjour._tcp"
  
  def self.list
    i = 0
    servers = {}
    service = DNSSD.browse(SERVICE) do |reply|
      servers[reply.name.chomp] ||= reply
    end
    STDERR.puts "Searching for servers (5 second)"
    # Wait for something to happen
    sleep 5
    service.stop
    puts "servers found: #{servers.size}"
    servers.each do |string,obj|
      DNSSD.resolve(obj.name, obj.type, obj.domain) do |rr|
        puts i += 1
        p rr
        p rr.text_record
        rr.text_record["hostnames"].split(',').each do |host|
          # don't add own hostnames
          unless rr.text_record["seed"] == @seed
            @@hosts ||= []
            @@hosts << Hostjour::Host.add(host, `resolveip -s #{rr.target.split(/\.?\:/).first}`, rr.text_record["identifier"])
          end
        end
      end
    end
    nil
  end
  
  def self.advertise(identifier = ENV["USER"])
    ct = Thread.current
    @@advertising_thread ||= Thread.new do
      tr = DNSSD::TextRecord.new
      tr["seed"] = @seed ||= rand(999999999).to_s
      tr["version"] = VERSION
      tr["identifier"] = identifier
      tr["primary_ip"] = get_ip
      tr["hostnames"] = []
  
      ::Host.list.each do |host|
        if host.ip == '127.0.0.1' || host.ip == get_ip
          tr["hostnames"] << host.hostname
        end
      end
  
      tr["hostnames"] = tr["hostnames"].uniq.join(',')
  
      name = `hostname`.gsub('.local','') || tr["identifier"]
  
      # Some random port for now
      DNSSD.register(name, SERVICE, "local", 9682, tr.encode) do |reply|
      end
    end
    
    ct.run
  end
  
  def self.get_ip
    # Hard code to airport for now
    @@ip ||= `ifconfig en1`.match(/inet ((?:\d{1,3}\.){3}\d{1,3})/)[1]
  rescue
    '0.0.0.0'
  end
end

# Hostjour.advertise
# sleep