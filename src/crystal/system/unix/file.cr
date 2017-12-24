require "c/sys/file"

# :nodoc:
module Crystal::System::File
  def self.open(filename, mode, perm)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename.check_no_null_byte, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end
    fd
  end

  def self.mktemp(name, extension)
    tmpdir = tempdir + ::File::SEPARATOR
    path = "#{tmpdir}#{name}.XXXXXX#{extension}"

    if extension
      fd = LibC.mkstemps(path, extension.bytesize)
    else
      fd = LibC.mkstemp(path)
    end

    raise Errno.new("mkstemp") if fd == -1
    {fd, path}
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    stat = uninitialized LibC::Stat
    if follow_symlinks
      ret = LibC.stat(path.check_no_null_byte, pointerof(stat))
    else
      ret = LibC.lstat(path.check_no_null_byte, pointerof(stat))
    end

    if ret == 0
      to_file_info(stat)
    else
      if {Errno::ENOENT, Errno::ENOTDIR}.includes? Errno.value
        return nil
      else
        raise Errno.new("Unable to get info for '#{path}'")
      end
    end
  end

  def self.to_file_info(stat)
    size = stat.st_size.to_u64

    permissions = ::File::Permissions.new((stat.st_mode & 0o777).to_i16)

    case stat.st_mode & LibC::S_IFMT
    when LibC::S_IFBLK
      type = ::File::Type::BlockDevice
    when LibC::S_IFCHR
      type = ::File::Type::CharacterDevice
    when LibC::S_IFDIR
      type = ::File::Type::Directory
    when LibC::S_IFIFO
      type = ::File::Type::Pipe
    when LibC::S_IFLNK
      type = ::File::Type::Symlink
    when LibC::S_IFREG
      type = ::File::Type::File
    when LibC::S_IFSOCK
      type = ::File::Type::Socket
    else
      raise "BUG: unknown File::Type"
    end

    flags = ::File::Flags::None
    flags |= ::File::Flags::SetUser if stat.st_mode.bits_set? LibC::S_ISUID
    flags |= ::File::Flags::SetGroup if stat.st_mode.bits_set? LibC::S_ISGID
    flags |= ::File::Flags::Sticky if stat.st_mode.bits_set? LibC::S_ISVTX

    modification_time = {% if flag?(:darwin) %}
                          ::Time.new(stat.st_mtimespec, ::Time::Location::UTC)
                        {% else %}
                          ::Time.new(stat.st_mtim, ::Time::Location::UTC)
                        {% end %}

    owner = stat.st_uid.to_u32
    group = stat.st_gid.to_u32

    ::File::Info.new(size, permissions, type, flags, modification_time, owner, group)
  end

  def self.exists?(path)
    accessible?(path, LibC::F_OK)
  end

  def self.readable?(path) : Bool
    accessible?(path, LibC::R_OK)
  end

  def self.writable?(path) : Bool
    accessible?(path, LibC::W_OK)
  end

  def self.executable?(path) : Bool
    accessible?(path, LibC::X_OK)
  end

  private def self.accessible?(path, flag)
    LibC.access(path.check_no_null_byte, flag) == 0
  end

  def self.chown(path, uid : Int, gid : Int, follow_symlinks)
    ret = if !follow_symlinks && ::File.symlink?(path)
            LibC.lchown(path, uid, gid)
          else
            LibC.chown(path, uid, gid)
          end
    raise Errno.new("Error changing owner of '#{path}'") if ret == -1
  end

  def self.chmod(path, mode)
    if LibC.chmod(path, mode) == -1
      raise Errno.new("Error changing permissions of '#{path}'")
    end
  end

  def self.delete(path)
    err = LibC.unlink(path.check_no_null_byte)
    if err == -1
      raise Errno.new("Error deleting file '#{path}'")
    end
  end

  def self.real_path(path)
    real_path_ptr = LibC.realpath(path, nil)
    raise Errno.new("Error resolving real path of #{path}") unless real_path_ptr
    String.new(real_path_ptr).tap { LibC.free(real_path_ptr.as(Void*)) }
  end

  def self.link(old_path, new_path)
    ret = LibC.link(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating link from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      raise Errno.new("Error renaming file '#{old_filename}' to '#{new_filename}'")
    end
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    timevals = uninitialized LibC::Timeval[2]
    timevals[0] = to_timeval(atime)
    timevals[1] = to_timeval(mtime)
    ret = LibC.utimes(filename, timevals)
    if ret != 0
      raise Errno.new("Error setting time to file '#{filename}'")
    end
  end

  private def self.to_timeval(time : ::Time)
    t = uninitialized LibC::Timeval
    t.tv_sec = typeof(t.tv_sec).new(time.to_local.epoch)
    t.tv_usec = typeof(t.tv_usec).new(0)
    t
  end

  private def system_truncate(size) : Nil
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise Errno.new("Error truncating file '#{path}'")
    end
  end

  private def system_flock_shared(blocking)
    flock LibC::FlockOp::SH, blocking
  end

  private def system_flock_exclusive(blocking)
    flock LibC::FlockOp::EX, blocking
  end

  private def system_flock_unlock
    flock LibC::FlockOp::UN
  end

  private def flock(op : LibC::FlockOp, blocking : Bool = true)
    op |= LibC::FlockOp::NB unless blocking

    if LibC.flock(@fd, op) != 0
      raise Errno.new("flock")
    end

    nil
  end
end
