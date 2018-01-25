require "c/int_safe"

lib LibC
  fun GetProcessId(process : HANDLE) : DWORD
  fun GetCurrentProcessId : DWORD
end
