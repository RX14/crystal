require "c/io"

module Crystal::System::FileDescriptor
  @fd : LibC::Int

  private def unbuffered_read(slice : Bytes)
    bytes_read = LibC._read(@fd, slice, slice.size)
    if bytes_read == -1
      raise Errno.new("Error reading file")
    end
    bytes_read
  end

  private def unbuffered_write(slice : Bytes)
    loop do
      bytes_written = LibC._write(@fd, slice, slice.size)
      if bytes_written == -1
        raise Errno.new("Error writing file")
      end

      slice += bytes_written
      return if slice.size == 0
    end
  end

  private def system_blocking?
    true
  end

  private def system_blocking=(blocking)
    raise NotImplementedError.new("Crystal::System::FileDescriptor#system_blocking=") unless blocking
  end

  private def system_close_on_exec?
    false
  end

  private def system_close_on_exec=(close_on_exec)
    raise NotImplementedError.new("Crystal::System::FileDescriptor#system_close_on_exec=") if close_on_exec
  end

  private def windows_handle
    ret = LibC._get_osfhandle(@fd)
    raise Errno.new("_get_osfhandle") if ret == -1
    LibC::HANDLE.new(ret)
  end

  private def system_info
    handle = windows_handle

    case LibC.GetFileType(handle)
    when LibC::FILE_TYPE_UNKNOWN
      raise WinError.new("GetFileType")
    when LibC::FILE_TYPE_PIPE then File::FILE_INFO_PIPE
    when LibC::FILE_TYPE_CHAR then File::FILE_INFO_CHARDEV
    when LibC::FILE_TYPE_DISK
      if LibC.GetFileInformationByHandle(handle, out file_info) == 0
        raise WinError.new("GetFileInformationByHandle")
      end

      File.to_file_info(file_info)
    else
      raise "BUG: unknown GetFileType result"
    end
  end

  private def system_seek(offset, whence : IO::Seek) : Nil
    seek_value = LibC._lseek(@fd, offset, whence)

    if seek_value == -1
      raise Errno.new "Unable to seek"
    end
  end

  private def system_pos
    pos = LibC._lseek(@fd, 0, IO::Seek::Current)
    raise Errno.new "Unable to tell" if pos == -1
    pos
  end

  private def system_tty?
    LibC._isatty(@fd) != 0
  end

  private def system_reopen(other : IO::FileDescriptor)
    {% if LibC.methods.includes? "dup3".id %}
      # dup doesn't copy the CLOEXEC flag, so copy it manually using dup3
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.fd, self.fd, flags) == -1
        raise Errno.new("Could not reopen file descriptor")
      end
    {% else %}
      # dup doesn't copy the CLOEXEC flag, copy it manually to the new
      if LibC.dup2(other.fd, self.fd) == -1
        raise Errno.new("Could not reopen file descriptor")
      end

      if other.close_on_exec?
        self.close_on_exec = true
      end
    {% end %}
  end

  private def system_close
    err = nil
    if LibC._close(@fd) != 0
      case Errno.value
      when Errno::EINTR
        # ignore
      else
        raise Errno.new("Error closing file")
      end
    end
  end

  def self.pipe(read_blocking, write_blocking)
    pipe_fds = uninitialized StaticArray(LibC::Int, 2)
    if LibC._pipe(pipe_fds, 8192, LibC::O_BINARY) != 0
      raise Errno.new("Could not create pipe")
    end

    r = IO::FileDescriptor.new(pipe_fds[0], read_blocking)
    w = IO::FileDescriptor.new(pipe_fds[1], write_blocking)
    w.sync = true

    {r, w}
  end
end
