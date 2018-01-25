# :nodoc:
module Crystal::System::Process
end

{% if flag?(:unix) %}
  require "./unix/process"
{% elsif flag?(:win32) %}
  require "./win32/process"
{% else %}
  {% raise "No Crystal::System::Process implementation available" %}
{% end %}
