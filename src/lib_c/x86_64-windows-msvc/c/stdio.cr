require "./stddef"

lib LibC
  fun printf(format : Char*, ...) : Int
  fun rename(old : Char*, new : Char*) : Int
  fun vsnprintf(str : Char*, size : SizeT, format : Char*, ap : VaList) : Int
  fun snprintf = __crystal_snprintf(str : Char*, size : SizeT, format : Char*, ...) : Int

  P_WAIT    = 0
  P_NOWAIT  = 1
  P_OVERLAY = 2
  P_NOWAITO = 3
  P_DETACH  = 4

  fun _wspawnvp(mode : Int, cmdname : WCHAR*, argv : WCHAR**) : HANDLE
end

fun __crystal_snprintf(str : LibC::Char*, size : LibC::SizeT, format : LibC::Char*, ...) : LibC::Int
  VaList.open do |varargs|
    LibC.vsnprintf(str, size, format, varargs)
  end
end
