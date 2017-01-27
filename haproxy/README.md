## multibinder + HAProxy

HAProxy by default doesn't include support for zero-downtime reloads. multibinder was developed to work with HAProxy, and has some useful wrappers included that allow running multiple HAProxy instances with multibinder on the same machine, while enabling zero-downtime reloads. 

### Installation on Ubuntu 16.04

Install multibinder and dependencies:
```
sudo apt-get install -y haproxy ruby
sudo gem install multibinder
```

The multibinder systemd scripts automatically support multiple haproxy instances, so stop and disable the default haproxy service:
```
sudo systemctl stop haproxy
sudo systemctl disable haproxy
```

Install the `multibinder` and `haproxy-multi@` systemd service files, and start multibinder itself:
```
sudo cp $(gem environment gemdir)/gems/multibinder-0.0.4/haproxy/*.service /etc/systemd/system/
sudo systemctl daemon-reload

sudo systemctl enable multibinder
sudo systemctl start multibinder
```

Create your first haproxy service configuration file, replacing all bind IP/ports with ERB code like the following:
```
cat >/etc/haproxy/foo.cfg.erb <<EOF
global
    user haproxy
    group haproxy
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http-in
    bind <%= bind_tcp('0.0.0.0', 80) %>
EOF
```

Now start your multibinder-enabled haproxy `foo` service!
```
sudo systemctl enable haproxy-multi@foo
sudo systemctl start haproxy-multi@foo
```

You'll have a process tree like the following:
```
$ sudo systemctl status haproxy-multi@foo
● haproxy-multi@foo.service - HAProxy Load Balancer
   Loaded: loaded (/etc/systemd/system/haproxy-multi@.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2016-10-31 20:56:28 UTC; 1s ago
     Docs: man:haproxy(1)
           file:/usr/share/doc/haproxy/configuration.txt.gz
  Process: 3092 ExecStop=/bin/kill -TERM $MAINPID (code=exited, status=0/SUCCESS)
  Process: 3076 ExecReload=/bin/sh -c /usr/local/bin/multibinder-haproxy-erb /usr/sbin/haproxy -c -f ${CONFIG}; /bin/kill -USR2 $MAINPID (code=exited, status=0/SUCCESS)
  Process: 3105 ExecStartPre=/usr/local/bin/multibinder-haproxy-erb /usr/sbin/haproxy -f ${CONFIG} -c -q (code=exited, status=0/SUCCESS)
 Main PID: 3109 (multibinder-hap)
   CGroup: /system.slice/system-haproxy\x2dmulti.slice/haproxy-multi@foo.service
           ├─3109 /usr/bin/ruby2.3 /usr/local/bin/multibinder-haproxy-wrapper /usr/sbin/haproxy -Ds -f /etc/haproxy/foo.cfg.erb -p /run/haproxy-foo.pid
           ├─3113 /usr/sbin/haproxy -Ds -f /etc/haproxy/foo.cfg -p /run/haproxy-foo.pid
           └─3115 /usr/sbin/haproxy -Ds -f /etc/haproxy/foo.cfg -p /run/haproxy-foo.pid

Oct 31 20:56:28 ip-172-31-8-204 systemd[1]: Starting HAProxy Load Balancer...
Oct 31 20:56:28 ip-172-31-8-204 systemd[1]: Started HAProxy Load Balancer.
```

With multibinder running separately from the haproxy process(es):
```
$ sudo systemctl status multibinder
● multibinder.service - Multibinder
   Loaded: loaded (/etc/systemd/system/multibinder.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2016-10-31 20:50:05 UTC; 7min ago
 Main PID: 2751 (multibinder)
    Tasks: 2
   Memory: 4.9M
      CPU: 44ms
   CGroup: /system.slice/multibinder.service
           └─2751 /usr/bin/ruby2.3 /usr/local/bin/multibinder /run/multibinder.sock

Oct 31 20:50:05 ip-172-31-8-204 systemd[1]: Started Multibinder.
Oct 31 20:50:05 ip-172-31-8-204 multibinder[2751]: Listening for binds on control socket: /run/multibinder.sock
```

Reloading an haproxy instance safely can then be requested through systemctl:
```
$ sudo systemctl reload haproxy-multi@foo
```
