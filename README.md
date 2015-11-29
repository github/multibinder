### multibinder

multibinder is a tiny ruby server that makes writing zero-downtime-reload services simpler. It accepts connections on a UNIX domain socket and binds an arbitrary number of LISTEN sockets given their ip+port combinations. When a bind is requested, the LISTEN socket is sent over the UNIX domain socket using ancillary data. Subsequent identical binds receive the same LISTEN socket.

multibinder runs on its own, separate from the daemons that use the sockets. multibinder can be re-exec itself to take upgrades by sending it a `SIGUSR1` - existing binds will be retained across re-execs.

#### Server usage

After installing multibinder, you can run the multibinder daemon:

```
bundle exec multibinder /path/to/control.sock
```

#### Client usage

The multibinder library retrieves a socket from a local multibinder server, communicating over the socket you specify in the `MULTIBINDER_SOCK` environment variable (which has to be the same as specified when running multibinder, and the user must have permission to access the file).

```ruby
require 'multibinder'

server = MultiBinder.bind '127.0.0.1', 8000

# use the server socket
# ... server.accept ...
```

The socket has close-on-exec disabled and is ready to be used in Ruby or passed on to a real service like haproxy. For an example of using multibinder with haproxy, see [the haproxy test shim](https://github.com/theojulienne/multibinder/blob/master/test/haproxy_shim.rb).
