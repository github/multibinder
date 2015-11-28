doc = <<DOCOPT
Binder.

Usage:
  #{__FILE__} --control=<f>
  #{__FILE__} -h | --help

Options:
  -h --help      Show this screen.
  --control=<f>  Location of the UNIX socket used for controlling and binding.

DOCOPT

require 'docopt'
require 'socket'
require 'json'

class BinderServer
  def initialize(args)
    @control_file = args['--control']
  end

  def handle_client(s)
    loop do
      msg, _, _, _ = s.recvmsg
      break if msg.empty?
      request = JSON.parse(msg)
      puts "Request: #{request}"

      case request['method']
      when 'bind'
        do_bind s, request
      else
        response = { :error => { :code => -32601, :message => 'Method not found' } }
        s.sendmsg JSON.dump(response), 0, nil
      end
    end
  end

  def bind_to_env(bind)
    "BINDER_BIND__tcp__#{bind['address'].sub('.','_')}__#{bind['port']}"
  end

  def do_bind(s, request)
    bind = request['params'][0]

    begin
      name = bind_to_env(bind)
      if ENV[name]
        socket = IO.for_fd ENV[name].to_i
      else
        socket = Socket.new(:INET, :STREAM, 0)
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
        socket.bind(Addrinfo.tcp(bind['address'], bind['port']))
        socket.listen(bind['backlog'] || 1000)
        ENV[name] = socket.fileno.to_s
      end
    rescue Exception => e
      response = {
        :jsonrpc => '2.0',
        :id => request['id'],
        :error => {
          :code => 10000,
          :message => "Could not bind: #{e.message}",
          :backtrace => e.backtrace,
        },
      }
      s.sendmsg JSON.dump(response), 0, nil
      return
    else
      response = {
        :jsonrpc => '2.0',
        :id => request['id'],
        :result => true,
      }
      s.sendmsg JSON.dump(response), 0, nil, Socket::AncillaryData.unix_rights(socket)
    end
  end

  def bind_accept_loop
    UNIXServer.open(@control_file) do |serv|
      puts "Listening for binds on control socket: #{@control_file}"

      Signal.trap("USR1") do
        @control_file.close
        File.unlink @control_file

        # respawn ourselved in an identical way, keeping state through environment.
        exec [RbConfig.ruby, $0] + ARGV
      end

      loop do
        s = serv.accept
        begin
          handle_client s
        rescue Exception => e
          puts e
          puts e.backtrace
        ensure
          s.close
        end
      end
    end
  end

  def serve
    begin
      File.unlink @control_file
      puts "Removed existing control socket: #{@control_file}"
    rescue Errno::ENOENT
      # :+1:
    end

    begin
      bind_accept_loop
    ensure
      File.unlink @control_file
    end
  end
end

begin
  server = BinderServer.new Docopt::docopt(doc)
  server.serve
rescue Docopt::Exit => e
  puts e.message
end
