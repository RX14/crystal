module HTTP::FormData
  # Parses a multipart/form-data message, yielding a `FormData::Parser` object
  # to register callbacks on using `Parser#field` and `Parser#file`.
  #
  # ```
  # form_data = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # HTTP::FormData.parse(MemoryIO.new(form_data), "aA40") do |parser|
  #   parser.field("field1") do |data|
  #     data # => "field data"
  #   end
  # end
  # ```
  #
  # See: `FormData::Parser`
  def self.parse(io, boundary)
    parser = Parser.new(io, boundary)
    yield parser
    parser.run
  end

  # Parses a multipart/form-data message, yielding a `FormData::Parser` object
  # to register callbacks on using `Parser#field` and `Parser#file`.
  #
  # ```
  # headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=aA40"}
  # body = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # request = HTTP::Request.new("POST", "/", headers, body)
  #
  # HTTP::FormData.parse(request) do |parser|
  #   parser.field("field1") do |data|
  #     data # => "field data"
  #   end
  # end
  # ```
  #
  # See: `FormData::Parser`
  def self.parse(request : HTTP::Request)
    body = request.body
    raise ParseException.new "Cannot parse HTTP request: body is empty" unless body

    boundary = request.headers["Content-Type"]?.try { |header| Multipart.parse_boundary(header) }
    raise ParseException.new "Cannot parse HTTP request: could not find boundary in Content-Type" unless boundary

    parse(MemoryIO.new(body), boundary) { |parser| yield parser }
  end

  # Generates a multipart/form-data message, yielding a `FormData::Generator`
  # object to the block which writes to *io* using *boundary*.
  # `Generator#finish` is called on the generator when the block returns.
  #
  # ```
  # io = MemoryIO.new
  # HTTP::FormData.generate(io, "boundary") do |generator|
  #   generator.field("foo", "bar")
  # end
  # io.to_s # => "--boundary\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--boundary--"
  # ```
  #
  # See: `FormData::Generator`
  def self.generate(io, boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    generator = Generator.new(io, boundary)
    yield generator
    generator.finish
  end

  # Generates a multipart/form-data message, yielding a `FormData::Generator`
  # object to the block which writes to *response* using *boundary.
  # Content-Type is set on *response* and `Generator#finish` is called on the
  # generator when the block returns.
  #
  # ```
  # io = MemoryIO.new
  # response = HTTP::Server::Response.new io
  # HTTP::FormData.generate(response, "boundary") do |generator|
  #   generator.field("foo", "bar")
  # end
  # response.close
  #
  # response.headers["Content-Type"] # => "multipart/form-data; boundary=\"boundary\""
  # io.to_s                          # => "HTTP/1.1 200 OK\r\nContent-Type: multipart/form-data; boundary=\"boundary\"\r\n ...
  # ```
  #
  # See: `FormData::Generator`
  def self.generate(response : HTTP::Server::Response, boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    generator = Generator.new(response, boundary)
    yield generator
    generator.finish
    response.headers["Content-Type"] = generator.content_type
  end

  # Metadata which may be available for uploaded files.
  record FileMetadata,
    filename : String? = nil,
    creation_time : Time? = nil,
    modification_time : Time? = nil,
    read_time : Time? = nil,
    size : UInt64? = nil
end
