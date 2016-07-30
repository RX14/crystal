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

  # Metadata which may be available for uploaded files.
  record FileMetadata,
    filename : String? = nil,
    creation_time : Time? = nil,
    modification_time : Time? = nil,
    read_time : Time? = nil,
    size : UInt64? = nil
end
