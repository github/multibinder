require "multibinder/version"

module MultiBinder
  def self.bind(address, port)
    @@binder ||= UNIXSocket.open(ENV['BINDER_SOCK'])

    # make the request
    @@binder.sendmsg JSON.dump({
      :jsonrpc => '2.0',
      :method => 'bind',
      :params => [{
        :address => address,
        :port => port,
      }]
    }, 0, nil)

    # get the response
    msg, _, _, ctl = @@binder.recvmsg(:scm_rights=>true)
    response = JSON.parse(msg)
    if response['error']
      raise response['error']['message']
    end

    return ctl.unix_rights[0]
  end

  def self.done
    @@binder.close
  end
end
