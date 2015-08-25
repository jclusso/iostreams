module IOStreams
  module Delimited
    class Reader
      attr_accessor :delimiter

      # Read from a file or stream
      def self.open(file_name_or_io, options={}, &block)
        if file_name_or_io.respond_to?(:read)
          block.call(new(file_name_or_io, options))
        else
          ::File.open(file_name_or_io, 'rb') do |io|
            block.call(new(io, options))
          end
        end
      end

      # Create a delimited UTF8 stream reader from the supplied input streams
      #
      # The input stream should be binary with no text conversions performed
      # since `strip_non_printable` will be applied to the binary stream before
      # converting to UTF-8
      #
      # Parameters
      #   input_stream
      #     The input stream that implements #read
      #
      #   options
      #     :delimiter[Symbol|String]
      #       Line / Record delimiter to use to break the stream up into records
      #         nil
      #           Automatically detect line endings and break up by line
      #           Searches for the first "\r\n" or "\n" and then uses that as the
      #           delimiter for all subsequent records
      #         String:
      #           Any string to break the stream up by
      #           The records when saved will not include this delimiter
      #       Default: nil
      #
      #     :buffer_size [Integer]
      #       Maximum size of the buffer into which to read the stream into for
      #       processing.
      #       Must be large enough to hold the entire first line and its delimiter(s)
      #       Default: 65536 ( 64K )
      #
      #     :strip_non_printable [true|false]
      #       Strip all non-printable characters read from the file
      #       Default: true
      #
      #     :utf8 [true|false]
      #       Force encoding to UTF-8 for all data being read
      #       Default: true
      def initialize(input_stream, options={})
        @input_stream        = input_stream
        options              = options.dup
        @delimiter           = options.delete(:delimiter)
        @buffer_size         = options.delete(:buffer_size) || 65536
        @strip_non_printable = options.delete(:strip_non_printable)
        @strip_non_printable = true if @strip_non_printable.nil?
        @utf8                = options.delete(:utf8)
        @utf8                = true if @utf8.nil?
        raise ArgumentError.new("Unknown IOStreams::DelimitedReader#initialize options: #{options.inspect}") if options.size > 0

        @delimiter.force_encoding(UTF8_ENCODING) if @delimiter && @utf8
        @buffer = ''
      end

      # Returns each line at a time to to the supplied block
      def each_line(&block)
        loop do
          partial = ''
          break if read_chunk == 0

          self.delimiter ||= detect_delimiter
          end_index      ||= (delimiter.size + 1) * -1

          @buffer.each_line(delimiter) do |line|
            if line.end_with?(delimiter)
              # Strip off delimiter
              block.call(line[0..end_index])
            else
              partial = line
            end
          end
          @buffer = partial
        end
      end

      ##########################################################################
      private

      # Returns [Integer] the number of bytes read into the internal buffer
      # Returns 0 on EOF
      def read_chunk
        chunk = @input_stream.read(@buffer_size)
        # EOF reached?
        return 0 unless chunk

        # Strip out non-printable characters before converting to UTF-8
        chunk = chunk.scan(/[[:print:]]|\r|\n/).join if @strip_non_printable

        @buffer << (@utf8 ? chunk.force_encoding(UTF8_ENCODING) : chunk)
        chunk.size
      end

      # Auto detect text line delimiter
      def detect_delimiter
        if @buffer =~ /\r\n?|\n/
          $&
        elsif @buffer.size <= @buffer_size
          # Handle one line files that are smaller than the buffer size
          "\n"
        else
          # TODO Add custom Exception
          raise "Malformed data. Could not find \\r\\n or \\n within the buffer_size of #{@buffer_size}. Read #{@buffer.size} bytes from stream"
        end
      end

    end
  end
end