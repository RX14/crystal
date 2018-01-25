require "c/processthreadsapi"

module Crystal::System::Process
  def self.current_pid
    LibC.GetCurrentProcessId
  end

  def self.current_gid
    raise NotImplementedError.new("Process.pgid")
  end

  def self.process_gid(pid)
    raise NotImplementedError.new("Process.pgid")
  end

  def self.parent_pid
    # TODO: Implement this using CreateToolhelp32Snapshot
    raise NotImplementedError.new("Process.ppid")
  end

  def self.fork
    raise NotImplementedError.new("Process.fork")
  end

  def self.spawn(command, args, env, clear_env, input, output, error, chdir)
    raise NotImplementedError.new("Process.new with env or clear_env options") if env || clear_env
    unless input == output == error == ::Process::Redirect::Inherit
      raise NotImplementedError.new("Process.new with input, output, or error set")
    end
    raise NotImplementedError.new("Process.new with chdir set") if chdir

    argv = [to_windows_string(command)]
    args.try &.each do |arg|
      argv << to_windows_string(arg)
    end
    argv << Pointer(UInt16).null

    handle = LibC._wspawnvp(LibC::P_NOWAIT, to_windows_string(command), argv)
    if handle == LibC::INVALID_HANDLE_VALUE
      raise Errno.new("spawn")
    end

    LibC.GetProcessId(handle).to_i32
  end

  def self.replace(command, argv, env, clear_env, input, output, error, chdir) : NoReturn
    raise NotImplementedError.new("Process.exec")
  end

  def self.wait(pid)
    raise NotImplementedError.new("Process#wait")
  end

  def self.kill(pid, signal)
    raise NotImplementedError.new("Process.kill with signals other than Signal::KILL") unless signal.kill?
    raise NotImplementedError.new("Process.kill")
  end

  private def self.to_windows_string(string : String) : LibC::LPWSTR
    string.check_no_null_byte.to_utf16.to_unsafe
  end
end
