require "http"
require "spec"

describe HTTP::FormData do
  describe ".parse(IO, String)" do
    it "parses formdata" do
      formdata = <<-FORMDATA
        --foo
        Content-Disposition: form-data; name="foo"

        bar
        --foo--
        FORMDATA

      res = nil
      HTTP::FormData.parse(MemoryIO.new(formdata.gsub('\n', "\r\n")), "foo") do |p|
        p.field("foo") { |content| res = content }
      end
      res.should eq("bar")
    end
  end

  describe ".parse(HTTP::Request)" do
    it "parses formdata" do
      formdata = <<-FORMDATA
        --foo
        Content-Disposition: form-data; name="foo"

        bar
        --foo--
        FORMDATA
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=foo"}
      request = HTTP::Request.new("GET", "/", headers, formdata.gsub('\n', "\r\n"))

      res = nil
      HTTP::FormData.parse(request) do |p|
        p.field("foo") { |content| res = content }
      end
      res.should eq("bar")
    end

    it "raises on empty body" do
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=foo"}
      req = HTTP::Request.new("GET", "/", headers)
      expect_raises(HTTP::FormData::ParseException, "Cannot parse HTTP request: body is empty") do
        HTTP::FormData.parse(req) { }
      end
    end

    it "raises on no Content-Type" do
      req = HTTP::Request.new("GET", "/", body: "")
      expect_raises(HTTP::FormData::ParseException, "Cannot parse HTTP request: could not find boundary in Content-Type") do
        HTTP::FormData.parse(req) { }
      end
    end

    it "raises on invalid Content-Type" do
      headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary="}
      req = HTTP::Request.new("GET", "/", headers, body: "")
      expect_raises(HTTP::FormData::ParseException, "Cannot parse HTTP request: could not find boundary in Content-Type") do
        HTTP::FormData.parse(req) { }
      end
    end
  end

  describe ".generate(IO, String)" do
    it "generates a message" do
      io = MemoryIO.new
      HTTP::FormData.generate(io, "boundary") do |g|
        g.field("foo", "bar")
      end

      expected = <<-MULTIPART
        --boundary
        Content-Disposition: form-data; name="foo"

        bar
        --boundary--
        MULTIPART
      io.to_s.should eq(expected.gsub('\n', "\r\n"))
    end
  end

  describe ".generate(HTTP::Response, String)" do
    it "generates a message" do
      io = MemoryIO.new
      response = HTTP::Server::Response.new(io)
      HTTP::FormData.generate(response, "boundary") do |g|
        g.field("foo", "bar")
      end
      response.close

      expected = <<-MULTIPART
        HTTP/1.1 200 OK
        Content-Type: multipart/form-data; boundary="boundary"
        Content-Length: 75

        --boundary
        Content-Disposition: form-data; name="foo"

        bar
        --boundary--
        MULTIPART

      io.to_s.should eq(expected.gsub('\n', "\r\n"))
    end
  end
end
