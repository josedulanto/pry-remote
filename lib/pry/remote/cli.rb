require 'drb'
require 'pry'
require 'slop'
require 'socket'

require_relative './io_undumped_proxy'
require_relative './server'

class Pry
  module Remote
    class CLI
      attr_reader :args, :capture, :host, :persist, :port, :wait

      alias wait? wait
      alias persist? persist
      alias capture? capture

      def initialize(args = ARGV)
        @args = args

        exit if options.help?

        @host = options[:server]
        @port = options[:port]

        @capture = options[:capture]
        @persist = options[:persist]
        @wait = options[:wait]

        Pry.initial_session_setup unless options[:f]
      end

      def run
        loop do
          connect
          break unless persist?
        end
      end

      def uri
        "druby://#{host}:#{port}"
      end

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

        client.editor = proc do |initial_content, line|
          # Hack to use Pry::Editor
          Pry::Editor.new(Pry.new).edit_tempfile_with_content(initial_content, line)
        end

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

      private

      def options
        @options ||= Slop.parse args, help: true do
          banner "#$PROGRAM_NAME [OPTIONS]"

          on :s, :server=, "Host of the server (#{Server::DEFAULT_HOST})", argument: :optional, default: Server::DEFAULT_HOST
          on :p, :port=, "Port of the server (#{Server::DEFAULT_PORT})", argument: :optional, as: Integer, default: Server::DEFAULT_PORT
          on :w, :wait, 'Wait for the pry server to come up', default: false
          on :r, :persist, 'Persist the client to wait for the pry server to come up each time', default: false
          on :c, :capture, 'Captures $stdout and $stderr from the server (true)', default: true
          on :f, 'Disables loading of .pryrc and its plugins, requires, and command history '
        end
      end
    end
  end
end
