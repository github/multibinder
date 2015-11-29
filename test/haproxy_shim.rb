require 'multibinder'

server = MultiBinder.bind '127.0.0.1', ARGV[0].to_i

cfg_fn = "#{ENV['TEMPDIR']}/haproxy.cfg"

File.write(cfg_fn, <<eos)
global
  maxconn 256

defaults
  mode http
  timeout connect 5000ms
  timeout client 50000ms
  timeout server 50000ms

frontend http-in
  bind fd@#{server.fileno}
  http-request deny
eos

pid = Process.spawn "haproxy", "-f", cfg_fn, :close_others => false

Signal.trap("INT") { Process.kill "USR1", pid }
Signal.trap("TERM") { Process.kill "USR1", pid }

Process.waitpid
