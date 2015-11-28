require 'socket'
require 'json'
require 'multibinder'

server = MultiBinder.bind '127.0.0.1', 8000
MultiBinder.done

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
