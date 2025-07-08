#ifndef DYNLIB_H
#define DYNLIB_H

#ifdef _WIN32
#include <windows.h>
typedef HMODULE dynlib_handle_t;
#define dynlib_open(path) LoadLibraryA(path)
#define dynlib_sym(handle, symbol) GetProcAddress(handle, symbol)
#define dynlib_close(handle) FreeLibrary(handle)
#define dynlib_error() "Windows DLL error"
#define DS_EXPORT __declspec(dllexport)
#else
#include <dlfcn.h>
typedef void *dynlib_handle_t;
#define dynlib_open(path) dlopen(path, RTLD_LAZY)
#define dynlib_sym(handle, symbol) dlsym(handle, symbol)
#define dynlib_close(handle) dlclose(handle)
#define dynlib_error() dlerror()
#define DS_EXPORT
#endif

#endif // DYNLIB_H
