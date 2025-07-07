#ifndef PY_COMMON_H
#define PY_COMMON_H

#include "core.h"
#include <Python.h>

// Copies the arguments and returns a new list of dictionaries, or NULL on error
// args: a list of dictionaries of the arguments
// kwargs: a dictionary of the arguments
// args_in: a list of the arguments
// returns: a new list of dictionaries, or NULL on error and sets an error
// message
argument_t *py_copy_and_parse_args(PyObject *args, PyObject *kwargs,
                                   const argument_t *args_in);

// Returns a list of dictionaries of the arguments, or NULL on error
// types: a string of types, one for each argument
// names: a list of names, one for each argument
// src(optional): a list of pointers to the source variables
PyObject *py_get_list_from_args(const argument_t *args_in, I return_values);

#endif // PY_COMMON_H
