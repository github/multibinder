multibinder
===

multibinder is a tiny ruby server that makes writing zero-downtime-reload services simpler. It accepts connections on a UNIX domain socket and binds an arbitrary number of LISTEN sockets given their ip+port combinations. When a bind is requested, the LISTEN socket is sent over the UNIX domain socket using ancillary data. Subsequent identical binds receive the same LISTEN socket.
