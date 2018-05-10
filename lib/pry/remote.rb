require 'pry'

require_relative './remote/server'

class Pry
  module Remote
  end
end

class Object
  # Starts a remote Pry session
  #
  # @param [String]  host Host of the server
  # @param [Integer] port Port of the server
  # @param [Hash] options Options to be passed to Pry.start
  def remote_pry(host = Pry::Remote::Server::DEFAULT_HOST, port = Pry::Remote::Server::DEFAULT_PORT, options = {})
    Pry::Remote::Server.new(self, host, port, options).run
  end

  # a handy alias as many people may think the method is named after the gem
  # (pry-remote)
  alias pry_remote remote_pry
end
