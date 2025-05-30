#ifndef PY_UTILS_H
#define PY_UTILS_H

#include <Python.h>
#include "core.h"

extern const char *ARG_TYPE_NATURAL;
extern const char *ARG_TYPE_INTEGER;
extern const char *ARG_TYPE_REAL;
extern const char *ARG_TYPE_STRING;

I parse_args(PyObject *args, PyObject *kwargs, argument_t *args_out);

PyObject *get_dict_from_args(const argument_t *args, N return_names);

#endif // PY_UTILS_H
