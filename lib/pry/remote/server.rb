require 'drb'
require 'open3'
require 'pry'

class Pry
  module Remote
    class Server
      DEFAULT_HOST = ENV['PRY_REMOTE_DEFAULT_HOST'] || '127.0.0.1'.freeze
      DEFAULT_PORT = ENV['PRY_REMOTE_DEFAULT_PORT'] || 9876

      def self.run(object, host = DEFAULT_HOST, port = DEFAULT_PORT, options = {})
        new(object, host, port, options).run
      end

      def initialize(object, host = DEFAULT_HOST, port = DEFAULT_PORT, options = {})
        @host    = host
        @port    = port

        @object  = object
        @options = options

        @client = Pry::Remote::Client.new
        DRb.start_service uri, @client
      end

      # Code that has to be called for Pry-remote to work properly
      def setup
        @hooks = Pry::Hooks.new

        @hooks.add_hook :before_eval, :pry_remote_capture do
          capture_output
        end

        @hooks.add_hook :after_eval, :pry_remote_uncapture do
          uncapture_output
        end

        # Ensure that system (shell command) output is redirected for remote session.
        system = proc do |output, cmd, _|
          status = nil
          Open3.popen3 cmd do |stdin, stdout, stderr, wait_thr|
            stdin.close # Send EOF to the process

            until stdout.eof? and stderr.eof?
              if res = IO.select([stdout, stderr])
                res[0].each do |io|
                  next if io.eof?
                  output.write io.read_nonblock(1024)
                end
              end
            end

            status = wait_thr.value
          end

          unless status.success?
            output.puts "Error while executing command: #{cmd}"
          end
        end

        # Before Pry starts, save the pager config.
        # We want to disable this because the pager won't do anything useful in
        # this case (it will run on the server).
        Pry.config.pager, @old_pager = false, Pry.config.pager

        # As above, but for system config
        Pry.config.system, @old_system = system, Pry.config.system

        Pry.config.editor, @old_editor = editor_proc, Pry.config.editor
      end

      # Code that has to be called after setup to return to the initial state
      def teardown
        # Reset config
        Pry.config.editor = @old_editor
        Pry.config.pager  = @old_pager
        Pry.config.system = @old_system

        puts "[pry-remote] Remote session terminated"

        begin
          @client.kill
        rescue DRb::DRbConnError
          puts "[pry-remote] Continuing to stop service"
        ensure
          puts "[pry-remote] Ensure stop service"
          DRb.stop_service
        end
      end

      # Captures $stdout and $stderr if so requested by the client.
      def capture_output
        @old_stdout, $stdout = if @client.stdout
                                 [$stdout, @client.stdout]
                               else
                                 [$stdout, $stdout]
                               end

        @old_stderr, $stderr = if @client.stderr
                                 [$stderr, @client.stderr]
                               else
                                 [$stderr, $stderr]
                               end
      end

      # Resets $stdout and $stderr to their previous values.
      def uncapture_output
        $stdout = @old_stdout
        $stderr = @old_stderr
      end

      def editor_proc
        proc do |file, line|
          File.write(file, @client.editor.call(File.read(file), line))
        end
      end

      # Actually runs pry-remote
      def run
        puts "[pry-remote] Waiting for client on #{uri}"
        @client.wait

        puts "[pry-remote] Client received, starting remote session"
        setup

        Pry.start(@object, @options.merge(:input => client.input_proxy,
                                          :output => client.output,
                                          :hooks => @hooks))
      ensure
        teardown
      end

      # @return Object to enter into
      attr_reader :object

      # @return [PryServer::Client] Client connecting to the pry-remote server
      attr_reader :client

      # @return [String] Host of the server
      attr_reader :host

      # @return [Integer] Port of the server
      attr_reader :port

      # @return [String] URI for DRb
      def uri
        "druby://#{host}:#{port}"
      end
    end
  end
end
