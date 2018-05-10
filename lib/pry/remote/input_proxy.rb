class Pry
  module Remote
    # Represents an input object created from DRb. This is used
    # because Pry checks for arity to know if a prompt should be passed to
    # the object.
    class InputProxy
      attr_reader :input

      def initialize(input)
        @input = input
      end

      def readline(prompt)
        case readline_arity
        when 1 then input.readline(prompt)
        else        input.readline
        end
      end

      def completion_proc=(val)
        input.completion_proc = val
      end

      def readline_arity
        input.method_missing(:method, :readline).arity
      rescue NameError
        0
      end
    end
  end
end
