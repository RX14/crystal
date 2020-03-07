lib LibC
  EPERM = 1 # Operation not permitted
  ENOENT = 2 # No such file or directory
  ESRCH = 3 # No such process
  EINTR = 4 # Interrupted system call
  EIO = 5 # Input/output error
  ENXIO = 6 # Device not configured
  E2BIG = 7 # Argument list too long
  ENOEXEC = 8 # Exec format error
  EBADF = 9 # Bad file descriptor
  ECHILD = 10 # No child processes
  EDEADLK = 11 # Resource deadlock avoided
  ENOMEM = 12 # Cannot allocate memory
  EACCES = 13 # Permission denied
  EFAULT = 14 # Bad address
  ENOTBLK = 15 # Block device required
  EBUSY = 16 # Device busy
  EEXIST = 17 # File exists
  EXDEV = 18 # Cross-device link
  ENODEV = 19 # Operation not supported by device
  ENOTDIR = 20 # Not a directory
  EISDIR = 21 # Is a directory
  EINVAL = 22 # Invalid argument
  ENFILE = 23 # Too many open files in system
  EMFILE = 24 # Too many open files
  ENOTTY = 25 # Inappropriate ioctl for device
  ETXTBSY = 26 # Text file busy
  EFBIG = 27 # File too large
  ENOSPC = 28 # No space left on device
  ESPIPE = 29 # Illegal seek
  EROFS = 30 # Read-only file system
  EMLINK = 31 # Too many links
  EPIPE = 32 # Broken pipe
  EDOM = 33 # Numerical argument out of domain
  ERANGE = 34 # Result too large or too small
  EAGAIN = 35 # Resource temporarily unavailable
  EWOULDBLOCK = EAGAIN # Operation would block
  EINPROGRESS = 36 # Operation now in progress
  EALREADY = 37 # Operation already in progress
  ENOTSOCK = 38 # Socket operation on non-socket
  EDESTADDRREQ = 39 # Destination address required
  EMSGSIZE = 40 # Message too long
  EPROTOTYPE = 41 # Protocol wrong type for socket
  ENOPROTOOPT = 42 # Protocol option not available
  EPROTONOSUPPORT = 43 # Protocol not supported
  ESOCKTNOSUPPORT = 44 # Socket type not supported
  EOPNOTSUPP = 45 # Operation not supported
  EPFNOSUPPORT = 46 # Protocol family not supported
  EAFNOSUPPORT = 47 # Address family not supported by protocol family
  EADDRINUSE = 48 # Address already in use
  EADDRNOTAVAIL = 49 # Can't assign requested address
  ENETDOWN = 50 # Network is down
  ENETUNREACH = 51 # Network is unreachable
  ENETRESET = 52 # Network dropped connection on reset
  ECONNABORTED = 53 # Software caused connection abort
  ECONNRESET = 54 # Connection reset by peer
  ENOBUFS = 55 # No buffer space available
  EISCONN = 56 # Socket is already connected
  ENOTCONN = 57 # Socket is not connected
  ESHUTDOWN = 58 # Can't send after socket shutdown
  ETOOMANYREFS = 59 # Too many references: can't splice
  ETIMEDOUT = 60 # Operation timed out
  ECONNREFUSED = 61 # Connection refused
  ELOOP = 62 # Too many levels of symbolic links
  ENAMETOOLONG = 63 # File name too long
  EHOSTDOWN = 64 # Host is down
  EHOSTUNREACH = 65 # No route to host
  ENOTEMPTY = 66 # Directory not empty
  EPROCLIM = 67 # Too many processes
  EUSERS = 68 # Too many users
  EDQUOT = 69 # Disc quota exceeded
  ESTALE = 70 # Stale NFS file handle
  EREMOTE = 71 # Too many levels of remote in path
  EBADRPC = 72 # RPC struct is bad
  ERPCMISMATCH = 73 # RPC version wrong
  EPROGUNAVAIL = 74 # RPC prog. not avail
  EPROGMISMATCH = 75 # Program version wrong
  EPROCUNAVAIL = 76 # Bad procedure for program
  ENOLCK = 77 # No locks available
  ENOSYS = 78 # Function not implemented
  EFTYPE = 79 # Inappropriate file type or format
  EAUTH = 80 # Authentication error
  ENEEDAUTH = 81 # Need authenticator
  EIDRM = 82 # Identifier removed
  ENOMSG = 83 # No message of desired type
  EOVERFLOW = 84 # Value too large to be stored in data type
  EILSEQ = 85 # Illegal byte sequence
  ENOTSUP = 86 # Not supported
  ECANCELED = 87 # Operation canceled
  EBADMSG = 88 # Bad or Corrupt message
  ENODATA = 89 # No message available
  ENOSR = 90 # No STREAM resources
  ENOSTR = 91 # Not a STREAM
  ETIME = 92 # STREAM ioctl timeout
  ENOATTR = 93 # Attribute not found
  EMULTIHOP = 94 # Multihop attempted 
  ENOLINK = 95 # Link has been severed
  EPROTO = 96 # Protocol error
end
