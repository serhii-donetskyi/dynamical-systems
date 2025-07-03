#ifndef PY_UTILS_H
#define PY_UTILS_H

#include <Python.h>


// Copies the arguments and returns a new list of dictionaries, or NULL on error
// args: a list of dictionaries of the arguments
// returns: a new list of dictionaries, or NULL on error
argument_t *copy_args(const argument_t *restrict args);

// Parses the arguments and returns a dictionary of the arguments, or NULL on error
// types: a string of types, one for each argument
// names: a list of names, one for each argument
// dest: a list of pointers to the destination variables
// returns: None on success, or NULL on error
PyObject *py_parse_args(PyObject *args, PyObject *kwargs, argument_t* args_out);

// Returns a list of dictionaries of the arguments, or NULL on error
// types: a string of types, one for each argument
// names: a list of names, one for each argument
// src(optional): a list of pointers to the source variables
PyObject *py_get_list_from_args(const argument_t* args_in, I return_values);


#endif // PY_UTILS_H
