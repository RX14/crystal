require "http"
require "spec"

def fd_parser(delim, data)
  data_io = MemoryIO.new(data.gsub("\n", "\r\n"))
  HTTP::FormData::Parser.new(data_io, delim)
end

def fd_parse_content_disposition(content_disposition, name)
  formdata = <<-FORMDATA
    --foo
    Content-Disposition: #{content_disposition}
    --foo--
    FORMDATA

  parser = fd_parser "foo", formdata

  meta = nil
  parser.file(name) { |_, _meta| meta = _meta }
  parser.run

  meta.not_nil!
end

describe HTTP::FormData::Parser do
  it "parses formdata" do
    formdata = <<-FORMDATA
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="text1"

      text default
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="text2"

      aωb
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file1"; filename="a.txt"
      Content-Type: text/plain

      Content of a.txt.

      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file2"; filename="a.html"
      Content-Type: text/html

      <!DOCTYPE html><title>Content of a.html.</title>

      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file3"; filename="binary"
      Content-Type: application/octet-stream

      aωb
      -----------------------------735323031399963166993862150--
      FORMDATA

    parser = fd_parser "---------------------------735323031399963166993862150", formdata

    runs = 0
    parser.field("text1") do |text|
      text.should eq("text default")
      runs += 1
    end

    parser.field("text2") do |text|
      text.should eq("aωb")
      runs += 1
    end

    parser.file("file1") do |io, meta, headers|
      io.gets_to_end.should eq("Content of a.txt.\r\n")
      meta.filename.should eq("a.txt")
      headers["Content-Type"].should eq("text/plain")
      runs += 1
    end

    parser.file("file2") do |io, meta, headers|
      io.gets_to_end.should eq("<!DOCTYPE html><title>Content of a.html.</title>\r\n")
      meta.filename.should eq("a.html")
      headers["Content-Type"].should eq("text/html")
      runs += 1
    end

    parser.file("file3") do |io, meta, headers|
      io.gets_to_end.should eq("aωb")
      meta.filename.should eq("binary")
      headers["Content-Type"].should eq("application/octet-stream")
      runs += 1
    end

    parser.run
    runs.should eq(5)
  end

  it "handles default callback" do
    formdata = <<-FORMDATA
      -----------------------------735323031399963166993862150
      Content-Disposition: form-data; name="file3"; filename="binary"
      Content-Type: application/octet-stream

      aωb
      -----------------------------735323031399963166993862150--
      FORMDATA

    parser = fd_parser "---------------------------735323031399963166993862150", formdata

    runs = 0
    parser.default do |name, io, meta, headers|
      name.should eq("file3")
      io.gets_to_end.should eq("aωb")
      meta.filename.should eq("binary")
      headers["Content-Type"].should eq("application/octet-stream")
      runs = 1
    end

    parser.run

    runs.should eq(1)
  end

  it "parses all Content-Disposition fields" do
    parsed = fd_parse_content_disposition %q(form-data; name=foo; filename="foo\"\\bar\ baz\\"; creation-date="Wed, 12 Feb 1997 16:29:51 -0500"; modification-date="12 Feb 1997 16:29:51 -0500"; read-date="Wed, 12 Feb 1997 16:29:51 -0500"; size=432334), "foo"

    parsed.filename.should eq(%q(foo"\bar baz\))
    parsed.creation_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
    parsed.modification_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
    parsed.read_time.should eq(Time.new(1997, 2, 12, 21, 29, 51, 0, kind: Time::Kind::Utc))
    parsed.size.should eq(432334)
  end
end
