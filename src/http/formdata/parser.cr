module HTTP::FormData
  class ParseException < Exception
  end

  # Parses a multipart/form-data message. Callbacks are used to process files
  # and fields.

  # ### Example
  #
  # ```
  # form_data = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # parser = HTTP::FormData::Parser.new(MemoryIO.new(form_data), "aA40")
  #
  # parser.field("field1") do |data|
  #   data # => "field data"
  # end
  #
  # parser.run
  # ```
  class Parser
    alias FieldCallback = String, HTTP::Headers ->
    alias FileCallback = IO, FileMetadata, HTTP::Headers ->
    alias DefaultFileCallback = String, IO, FileMetadata, HTTP::Headers ->

    @default_callback : DefaultFileCallback?

    # Create a new parser which parses *io* with multipart boundary *boundary*.
    def initialize(io, boundary)
      @multipart = Multipart::Parser.new(io, boundary)
      @callbacks = Hash(String, FieldCallback | FileCallback).new
      @default_callback = nil
    end

    # Add a callback on the form field with name *name*. This method should be
    # used for text fields, as it provides a string and optionally, any extra
    # headers on the field.
    #
    # ```
    # parser.field("field-name") do |str, headers|
    #   str     # => "field data"
    #   headers # => HTTP::Headers{ "Content-Disposition" => "form-data; name=\"field-name\"" }
    # end
    # ```
    def field(name, &block : FieldCallback)
      @callbacks[name] = block
    end

    # Add a callback on the form field with name *name*. This method should be
    # used on file-type form fields as it allows the file to be streamed, and
    # provides extra metadata.
    #
    # Please note that the IO object provided to the callback is only valid
    # while the block is executing. The IO is closed as soon as the callback
    # returns.
    #
    # ```
    # parser.file("upload") do |io, meta, headers|
    #   io.gets_to_end # => "file contents"
    #   meta.filename  # => "file.txt"
    #   meta.size      # => 13
    #   headers        # => HTTP::Headers{ "Content-Disposition" => "form-data; name=\"upload\"; filename=\"file.txt\"; size=13" }
    # end
    # ```
    def file(name, &block : FileCallback)
      @callbacks[name] = block
    end

    # Add a callback which is called when no other callbacks match.
    #
    # Please note that the IO object provided to the callback is only valid
    # while the block is executing. The IO is closed as soon as the callback
    # returns.
    #
    # ```
    # parser.default do |name, io, meta, headers|
    #   name           # => "upload"
    #   io.gets_to_end # => "file contents"
    #   meta.filename  # => "file.txt"
    #   meta.size      # => 13
    #   headers        # => HTTP::Headers{ "Content-Disposition" => "form-data; name=\"upload\"; filename=\"file.txt\"; size=13" }
    # end
    # ```
    def default(&block : DefaultFileCallback)
      @default_callback = block
    end

    # Starts parsing the multipart/form-data.
    def run
      fail "Parser has already been run" unless @multipart.has_next?

      while @multipart.has_next?
        @multipart.next do |headers, io|
          content_disposition = headers.get?("Content-Disposition").try &.[0]
          break unless content_disposition
          field_name, metadata = parse_content_disposition content_disposition
          callback = @callbacks[field_name]?
          if callback
            if callback.is_a? FieldCallback
              callback.call(io.gets_to_end, headers)
            else
              callback.call(io, metadata, headers)
            end
          else
            if cb = @default_callback
              cb.call(field_name, io, metadata, headers)
            end
          end
        end
      end
    end

    private def parse_content_disposition(content_disposition) : {String, FileMetadata}
      filename = nil
      creation_time = nil
      modification_time = nil
      read_time = nil
      size = nil
      name = nil

      parts = content_disposition.split(';')
      type = parts[0]
      fail "Invalid Content-Disposition: not form-data" unless type == "form-data"
      (1...parts.size).each do |i|
        part = parts[i]

        key, value = part.split('=', 2)
        key = key.strip
        value = value.strip
        if value[0] == '"'
          value = HTTP.dequote_string(value[1...-1])
        end

        case key
        when "filename"
          filename = value
        when "creation-date"
          creation_time = parse_time value
        when "modification-date"
          modification_time = parse_time value
        when "read-date"
          read_time = parse_time value
        when "creation-date"
          creation_time = parse_time value
        when "size"
          size = value.to_u64
        when "name"
          name = value
        end
      end

      fail "Invalid Content-Disposition: no name field" if name.nil?
      {name, FileMetadata.new(filename, creation_time, modification_time, read_time, size)}
    end

    private def parse_time(str)
      {"%a, %d %b %Y %H:%M:%S %z", "%d %b %Y %H:%M:%S %z"}.each do |pattern|
        begin
          return Time.parse(str, pattern, kind: Time::Kind::Utc)
        rescue Time::Format::Error
        end
      end

      nil
    end

    private def fail(message)
      raise ParseException.new(message)
    end
  end
end
