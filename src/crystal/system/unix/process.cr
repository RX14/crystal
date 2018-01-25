require "c/signal"
require "c/stdlib"
require "c/sys/times"
require "c/sys/wait"
require "c/unistd"

module Crystal::System::Process
  def self.current_pid
    LibC.getpid
  end

  def self.parent_pid
    LibC.getppid
  end

  def self.current_gid
    ret = LibC.getpgid(0)
    raise Errno.new("getpgid") if ret < 0
    ret
  end

  def self.process_gid(pid)
    # Disallow users from depending on ppid(0) instead of ppid
    raise Errno.new("getpgid", Errno::EINVAL) if pid == 0

    ret = LibC.getpgid(pid)
    raise Errno.new("getpgid") if ret < 0
    ret
  end

  def self.kill(pid, signal)
    ret = LibC.kill(pid, signal.value)
    raise Errno.new("kill") if ret < 0
  end

  def self.fork
    case pid = LibC.fork
    when -1
      raise Errno.new("fork")
    when 0
      nil
    else
      pid
    end
  end

  def self.spawn(command, args, env, clear_env, input, output, error, chdir)
    pid = self.fork

    if pid.nil?
      begin
        self.replace(command, args, env, clear_env, input, output, error, chdir)
      rescue ex
        ex.inspect_with_backtrace STDERR
      ensure
        LibC._exit 127
      end
    end

    pid
  end

  def self.replace(command, args, env, clear_env, input, output, error, chdir) : NoReturn
    reopen_io(input, STDIN, "r")
    reopen_io(output, STDOUT, "w")
    reopen_io(error, STDERR, "w")

    ENV.clear if clear_env
    env.try &.each do |key, val|
      if val
        ENV[key] = val
      else
        ENV.delete key
      end
    end

    ::Dir.cd(chdir) if chdir

    argv = [command.check_no_null_byte.to_unsafe]
    args.try &.each do |arg|
      argv << arg.check_no_null_byte.to_unsafe
    end
    argv << Pointer(UInt8).null

    LibC.execvp(command, argv)
    raise Errno.new("execvp")
  end

  def self.wait(pid)
    Event::SignalChildHandler.instance.waitpid(pid)
  end

  private def self.reopen_io(src_io, dst_io, mode)
    case src_io
    when IO::FileDescriptor
      src_io.blocking = true
      dst_io.reopen(src_io)
    when ::Process::Redirect::Inherit
      dst_io.blocking = true
    when ::Process::Redirect::Close
      ::File.open("/dev/null", mode) do |file|
        dst_io.reopen(file)
      end
    else
      raise "BUG: unknown object type #{src_io}"
    end

    dst_io.close_on_exec = false
  end
end
