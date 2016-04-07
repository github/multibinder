require 'multibinder/version'
require 'json'

module MultiBinder
  def self.bind(address, port, options={})
    abort 'MULTIBINDER_SOCK environment variable must be set' if !ENV['MULTIBINDER_SOCK']

    binder = UNIXSocket.open(ENV['MULTIBINDER_SOCK'])

    # make the request
    binder.sendmsg JSON.dump({
      :jsonrpc => '2.0',
      :method => 'bind',
      :params => [{
        :address => address,
        :port => port,
      }.merge(options)]
    }, 0, nil)

    # get the response
    msg, _, _, ctl = binder.recvmsg(:scm_rights=>true)
    response = JSON.parse(msg)
    if response['error']
      raise response['error']['message']
    end

    binder.close

    socket = ctl.unix_rights[0]
    socket.fcntl(Fcntl::F_SETFD, socket.fcntl(Fcntl::F_GETFD) & (-Fcntl::FD_CLOEXEC-1))
    socket
  end
end
