#ifndef PY_UTILS_H
#define PY_UTILS_H

#include <Python.h>
#include "core.h"


// Parses the arguments and returns a dictionary of the arguments, or NULL on error
// types: a string of types, one for each argument
// names: a list of names, one for each argument
// dest: a list of pointers to the destination variables
// returns: None on success, or NULL on error
PyObject *py_parse_args(PyObject *args, PyObject *kwargs, const char *types, const char *const *names, void **dest);

// Returns a list of dictionaries of the arguments, or NULL on error
// types: a string of types, one for each argument
// names: a list of names, one for each argument
// src(optional): a list of pointers to the source variables
PyObject *py_get_list_from_args(const char *types, const char *const *names, const void **src);

#endif // PY_UTILS_H
