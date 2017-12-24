require "c/io"
require "c/fcntl"
require "c/fileapi"
require "c/sys/utime"

module Crystal::System::File
  def self.open(filename : String, mode : String, perm : Int32 | ::File::Permissions) : LibC::Int
    perm = perm.value if perm.is_a? ::File::Permissions
    oflag = open_flag(mode) | LibC::O_BINARY

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if (perm & 0o200) == 0
      perm = LibC::S_IREAD
    else
      perm = LibC::S_IREAD | LibC::S_IWRITE
    end

    fd = LibC._wopen(to_windows_path(filename), oflag, perm)
    if fd == -1
      raise Errno.new("Error opening file #{filename.inspect} with mode #{mode.inspect}")
    end

    fd
  end

  def self.mktemp(name : String, extension : String?) : {LibC::Int, String}
    path = "#{tempdir}\\#{name}.#{::Random::Secure.hex}#{extension}"

    fd = LibC._wopen(to_windows_path(path), LibC::O_RDWR | LibC::O_CREAT | LibC::O_EXCL | LibC::O_BINARY, ::File::DEFAULT_CREATE_PERMISSIONS)
    if fd == -1
      raise Errno.new("Error creating temporary file at #{path.inspect}")
    end

    {fd, path}
  end

  def self.tempdir : String
    tmpdir = System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetTempPathW(buffer.size, buffer)
      if 0 < len < buffer.size
        break String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise WinError.new("Error while getting current directory")
      end
    end

    tmpdir.rchop("\\")
  end

  NOT_FOUND_ERRORS = {
    WinError::ERROR_FILE_NOT_FOUND,
    WinError::ERROR_PATH_NOT_FOUND,
    WinError::ERROR_INVALID_NAME,
  }

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    file_attributes = uninitialized LibC::WIN32_FILE_ATTRIBUTE_DATA
    ret = LibC.GetFileAttributesExW(
      to_windows_path(path),
      LibC::GET_FILEEX_INFO_LEVELS::GetFileExInfoStandard,
      pointerof(file_attributes)
    )

    if ret == 0
      error = LibC.GetLastError
      if NOT_FOUND_ERRORS.includes? error
        return nil
      else
        raise WinError.new("GetFileAttributesEx", error)
      end
    end

    info = to_file_info(file_attributes)
    return info unless follow_symlinks && info.type.symlink?

    # path is a symlink, we need to use CreateFile to stat
    handle = LibC.CreateFileW(
      to_windows_path(path),
      LibC::FILE_READ_ATTRIBUTES,
      LibC::FILE_SHARE_READ | LibC::FILE_SHARE_WRITE | LibC::FILE_SHARE_DELETE,
      nil,
      LibC::OPEN_EXISTING,
      LibC::FILE_FLAG_BACKUP_SEMANTICS,
      LibC::HANDLE.null
    )

    if handle != LibC::INVALID_HANDLE_VALUE
      begin
        if LibC.GetFileInformationByHandle(handle, out file_info) == 0
          raise WinError.new("GetFileInformationByHandle")
        end

        to_file_info(file_info)
      ensure
        LibC.CloseHandle(handle)
      end
    else
      error = LibC.GetLastError
      if NOT_FOUND_ERRORS.includes? error
        return nil
      else
        raise WinError.new("CreateFile", error)
      end
    end
  end

  def self.to_file_info(file_info)
    size = (file_info.nFileSizeHigh.to_u64 << 32) | file_info.nFileSizeLow.to_u64

    if file_info.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_READONLY
      permissions = ::File::Permissions.new(0o444)
    else
      permissions = ::File::Permissions.new(0o666)
    end

    if file_info.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_REPARSE_POINT
      type = ::File::Type::Symlink
    elsif file_info.dwFileAttributes.bits_set? LibC::FILE_ATTRIBUTE_DIRECTORY
      type = ::File::Type::Directory
      permissions |= ::File::Permissions.new(0o111)
    else
      type = ::File::Type::File
    end

    modification_time = Time.from_filetime(file_info.ftLastWriteTime)

    ::File::Info.new(size, permissions, type, ::File::Flags::None, modification_time, owner: 0_u32, group: 0_u32)
  end

  FILE_INFO_PIPE = ::File::Info.new(
    size: 0_u64,
    permissions: ::File::Permissions.new(0o666),
    type: ::File::Type::Pipe,
    flags: ::File::Flags::None,
    modification_time: ::Time.new(seconds: 0_i64, nanoseconds: 0, location: ::Time::Location::UTC),
    owner: 0_u32, group: 0_u32
  )

  FILE_INFO_CHARDEV = ::File::Info.new(
    size: 0_u64,
    permissions: ::File::Permissions.new(0o666),
    type: ::File::Type::CharacterDevice,
    flags: ::File::Flags::None,
    modification_time: ::Time.new(seconds: 0_i64, nanoseconds: 0, location: ::Time::Location::UTC),
    owner: 0_u32, group: 0_u32
  )

  def self.exists?(path)
    accessible?(path, 0)
  end

  def self.readable?(path) : Bool
    accessible?(path, 4)
  end

  def self.writable?(path) : Bool
    accessible?(path, 2)
  end

  def self.executable?(path) : Bool
    raise NotImplementedError.new("File.executable?")
  end

  private def self.accessible?(path, mode)
    LibC._waccess_s(to_windows_path(path), mode) == 0
  end

  def self.chown(path : String, uid : Int32, gid : Int32, follow_symlinks : Bool) : Nil
    raise NotImplementedError.new("File.chown")
  end

  def self.chmod(path : String, mode : Int32 | ::File::Permissions) : Nil
    mode = mode.value if mode.is_a? ::File::Permissions

    # Only the owner writable bit is used, since windows only supports
    # the read only attribute.
    if (mode & 0o200) == 0
      mode = LibC::S_IREAD
    else
      mode = LibC::S_IREAD | LibC::S_IWRITE
    end

    if LibC._wchmod(to_windows_path(path), mode) != 0
      raise Errno.new("Error changing permissions of #{path.inspect}")
    end
  end

  def self.delete(path : String) : Nil
    if LibC._wunlink(to_windows_path(path)) != 0
      raise Errno.new("Error deleting file #{path.inspect}")
    end
  end

  def self.real_path(path : String) : String
    # TODO: read links using https://msdn.microsoft.com/en-us/library/windows/desktop/aa364571(v=vs.85).aspx
    win_path = to_windows_path(path)

    System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetFullPathNameW(win_path, buffer.size, buffer, nil)
      if 0 < len < buffer.size
        return String.from_utf16(buffer[0, len])
      elsif small_buf && len > 0
        next len
      else
        raise WinError.new("Error resolving real path of #{path.inspect}")
      end
    end
  end

  def self.link(old_path : String, new_path : String) : Nil
    if LibC.CreateHardLinkW(to_windows_path(new_path), to_windows_path(old_path), nil) == 0
      raise WinError.new("Error creating hard link from #{old_path.inspect} to #{new_path.inspect}")
    end
  end

  def self.symlink(old_path : String, new_path : String) : Nil
    # TODO: support directory symlinks (copy Go's stdlib logic here)
    if LibC.CreateSymbolicLinkW(to_windows_path(new_path), to_windows_path(old_path), 0x2) == 0
      raise WinError.new("Error creating symbolic link from #{old_path.inspect} to #{new_path.inspect}")
    end
  end

  def self.rename(old_path : String, new_path : String) : Nil
    if LibC._wrename(to_windows_path(old_path), to_windows_path(new_path)) != 0
      raise Errno.new("Error renaming file from #{old_path.inspect} to #{new_path.inspect}")
    end
  end

  def self.utime(access_time : ::Time, modification_time : ::Time, path : String) : Nil
    times = LibC::Utimbuf64.new
    times.actime = access_time.epoch
    times.modtime = modification_time.epoch

    if LibC._wutime64(to_windows_path(path), pointerof(times)) != 0
      raise Errno.new("Error setting time on file #{path.inspect}")
    end
  end

  private def system_truncate(size : Int) : Nil
    if LibC._chsize(@fd, size) != 0
      raise Errno.new("Error truncating file #{path.inspect}")
    end
  end

  private def system_flock_shared(blocking : Bool) : Nil
    raise NotImplementedError.new("File#flock_shared")
  end

  private def system_flock_exclusive(blocking : Bool) : Nil
    raise NotImplementedError.new("File#flock_exclusive")
  end

  private def system_flock_unlock : Nil
    raise NotImplementedError.new("File#flock_unlock")
  end

  private def self.to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end
end
