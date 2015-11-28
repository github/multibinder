require 'socket'
require 'json'

binder = UNIXSocket.open(ENV['BINDER_SOCK'])
binder.sendmsg JSON.dump({
  :jsonrpc => '2.0',
  :method => 'bind',
  :params => [{
    :address => '127.0.0.1',
    :port => '8000'
  }]
}, 0, nil)
response, _, _, ctl = binder.recvmsg(:scm_rights=>true)
puts JSON.parse(response)
server = ctl.unix_rights[0]
binder.close

loop do
  socket, _ = server.accept
  request = socket.gets
  puts request

  socket.print "HTTP/1.0 200 OK\r\n"
  socket.print "Content-Type: text/plain\r\n"
  socket.print "Connection: close\r\n"

  socket.print "\r\n"

  socket.print "Hello World!\n"

  socket.close
end
