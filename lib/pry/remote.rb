require 'pry'
require 'slop'
require 'drb'

require_relative './remote/client'
require_relative './remote/io_undumped_proxy'
require_relative './remote/server'

class Pry
  module Remote
    ClientEditor = proc do |initial_content, line|
      # Hack to use Pry::Editor
      Pry::Editor.new(Pry.new).edit_tempfile_with_content(initial_content, line)
    end

    # Parses arguments and allows to start the client.
    class CLI
      def initialize(args = ARGV)
        params = Slop.parse args, :help => true do
          banner "#$PROGRAM_NAME [OPTIONS]"

          on :s, :server=, "Host of the server (#{Server::DEFAULT_HOST})", :argument => :optional,
             :default => Server::DEFAULT_HOST
          on :p, :port=, "Port of the server (#{Server::DEFAULT_PORT})", :argument => :optional,
             :as => Integer, :default => Server::DEFAULT_PORT
          on :w, :wait, "Wait for the pry server to come up",
             :default => false
          on :r, :persist, "Persist the client to wait for the pry server to come up each time",
             :default => false
          on :c, :capture, "Captures $stdout and $stderr from the server (true)",
             :default => true
          on :f, "Disables loading of .pryrc and its plugins, requires, and command history "
        end

        exit if params.help?

        @host = params[:server]
        @port = params[:port]

        @wait = params[:wait]
        @persist = params[:persist]
        @capture = params[:capture]

        Pry.initial_session_setup unless params[:f]
      end

      # @return [String] Host of the server
      attr_reader :host

      # @return [Integer] Port of the server
      attr_reader :port

      # @return [String] URI for DRb
      def uri
        "druby://#{host}:#{port}"
      end

      attr_reader :wait
      attr_reader :persist
      attr_reader :capture
      alias wait? wait
      alias persist? persist
      alias capture? capture

      def run
        while true
          connect
          break unless persist?
        end
      end

      # Connects to the server
      #
      # @param [IO] input  Object holding input for pry-remote
      # @param [IO] output Object pry-debug will send its output to
      def connect(input = Pry.config.input, output = Pry.config.output)
        local_ip = UDPSocket.open {|s| s.connect(@host, 1); s.addr.last}
        DRb.start_service "druby://#{local_ip}:0"
        client = DRbObject.new(nil, uri)

        cleanup(client)

        input  = IOUndumpedProxy.new(input)
        output = IOUndumpedProxy.new(output)

        begin
          client.input  = input
          client.output = output
        rescue DRb::DRbConnError => ex
          if wait? || persist?
            sleep 1
            retry
          else
            raise ex
          end
        end

        if capture?
          client.stdout = $stdout
          client.stderr = $stderr
        end

        client.editor = ClientEditor

        client.thread = Thread.current

        sleep
        DRb.stop_service
      end

      # Clean up the client
      def cleanup(client)
        begin
          # The method we are calling here doesn't matter.
          # This is a hack to close the connection of DRb.
          client.cleanup
        rescue DRb::DRbConnError, NoMethodError
        end
      end
    end
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
