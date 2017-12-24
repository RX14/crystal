require "c/winnt"

lib LibC
  fun GetFullPathNameW(lpFileName : LPWSTR, nBufferLength : DWORD, lpBuffer : LPWSTR, lpFilePart : LPWSTR*) : DWORD
  fun GetTempPathW(nBufferLength : DWORD, lpBuffer : LPWSTR) : DWORD

  FILE_TYPE_CHAR    = 0x2
  FILE_TYPE_DISK    = 0x1
  FILE_TYPE_PIPE    = 0x3
  FILE_TYPE_UNKNOWN = 0x0

  fun GetFileType(hFile : HANDLE) : DWORD

  struct BY_HANDLE_FILE_INFORMATION
    dwFileAttributes : DWORD
    ftCreationTime : FILETIME
    ftLastAccessTime : FILETIME
    ftLastWriteTime : FILETIME
    dwVolumeSerialNumber : DWORD
    nFileSizeHigh : DWORD
    nFileSizeLow : DWORD
    nNumberOfLinks : DWORD
    nFileIndexHigh : DWORD
    nFileIndexLow : DWORD
  end

  fun GetFileInformationByHandle(hFile : HANDLE, lpFileInformation : BY_HANDLE_FILE_INFORMATION*) : BOOL
  fun GetFileAttributesExW(lpFileName : LPWSTR, fInfoLevelId : GET_FILEEX_INFO_LEVELS, lpFileInformation : Void*) : BOOL

  OPEN_EXISTING = 3

  FILE_FLAG_BACKUP_SEMANTICS = 0x02000000

  FILE_SHARE_READ = 0x1
  FILE_SHARE_WRITE = 0x2
  FILE_SHARE_DELETE = 0x4

  fun CreateFileW(lpFileName : LPWSTR, dwDesiredAccess : DWORD, dwShareMode : DWORD,
                  lpSecurityAttributes : SECURITY_ATTRIBUTES*, dwCreationDisposition : DWORD,
                  dwFlagsAndAttributes : DWORD, hTemplateFile : HANDLE) : HANDLE

  MAX_PATH = 260

  struct WIN32_FIND_DATAW
    dwFileAttributes : DWORD
    ftCreationTime : FILETIME
    ftLastAccessTime : FILETIME
    ftLastWriteTime : FILETIME
    nFileSizeHigh : DWORD
    nFileSizeLow : DWORD
    dwReserved0 : DWORD
    dwReserved1 : DWORD
    cFileName : WCHAR[MAX_PATH]
    cAlternateFileName : WCHAR[14]
  end

  fun FindFirstFileW(lpFileName : LPWSTR, lpFindFileData : WIN32_FIND_DATAW*) : HANDLE
  fun FindNextFileW(hFindFile : HANDLE, lpFindFileData : WIN32_FIND_DATAW*) : BOOL
  fun FindClose(hFindFile : HANDLE) : BOOL
end
