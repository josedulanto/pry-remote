require_relative './input_proxy'

class Pry
  module Remote
    # A client is used to retrieve information from the client program.
    class Client
      def initilaize(input, output, thread, stdout, stderr)
        @input = input
        @output = output
        @thread = thread
        @stdout = stdout
        @stderr = stderr
      end

      # Waits until both an input and output are set
      def wait
        sleep 0.01 until input && output && thread
      end

      # Tells the client the session is terminated
      def kill
        thread.run
      end

      # @return [InputProxy] Proxy for the input
      def input_proxy
        InputProxy.new input
      end
    end
  end
end
