#include "py_common.h"
#include "core.h"
#include <Python.h>

const char *ARG_TYPE_NATURAL = "NATURAL";
const char *ARG_TYPE_INTEGER = "INTEGER";
const char *ARG_TYPE_REAL = "REAL";
const char *ARG_TYPE_STRING = "STRING";

// Returns the number of arguments parsed (excluding the sentinel), or -1 on error
I parse_args(PyObject *args, PyObject *kwargs, argument_t *args_out) {

    if (!args_out){
        PyErr_SetString(PyExc_RuntimeError, "Arguments must contain a sentinel");
        return -1;
    }

    // Count number of arguments
    N arg_size = 0;
    while (args_out[arg_size++].name);
    arg_size--; // Adjust for the extra increment

    // Check if we have the correct number of arguments
    Py_ssize_t nargs = PyTuple_GET_SIZE(args);
    Py_ssize_t nkwargs = kwargs ? PyDict_Size(kwargs) : 0;
    
    if (nargs + nkwargs != (Py_ssize_t)arg_size) {
        PyErr_Format(PyExc_TypeError, "Expected %d arguments, got %zd", (int)arg_size, nargs + nkwargs);
        return -1;
    }

    // Parse each argument
    for (N i = 0; i < arg_size; i++) {
        PyObject *arg = NULL;
        
        // Try to get argument from positional args first
        if ((Py_ssize_t)i < nargs) {
            arg = PyTuple_GET_ITEM(args, i);
        }
        // If not in positional args and we have keyword args, try to get from kwargs
        else if (kwargs) {
            arg = PyDict_GetItemString(kwargs, args_out[i].name);
        }

        // If we still don't have an argument, it's an error
        if (!arg) {
            PyErr_Format(PyExc_TypeError, "Missing required argument '%s'", args_out[i].name);
            return -1;
        }

        switch (args_out[i].type) {
            case NATURAL:
                args_out[i].n = PyLong_AsUnsignedLong(arg);
                break;
            case INTEGER:
                args_out[i].i = PyLong_AsLong(arg);
                break;
            case REAL:
                args_out[i].r = PyFloat_AsDouble(arg);
                break;
            case STRING:
                args_out[i].s = PyUnicode_AsUTF8(arg);
                break;
            default:
                PyErr_SetString(PyExc_RuntimeError, "Invalid argument type");
                return -1;
        }
        if (PyErr_Occurred()) return -1;
    }

    return arg_size;
}

// Returns a dictionary of the arguments, or NULL on error
PyObject *get_dict_from_args(const argument_t *args, N return_names) {
    PyObject *dict = PyDict_New();
    if (!dict) return NULL;
    
    for (N i = 0; args[i].name; i++) {
        PyObject *value = NULL;
        switch (args[i].type) {
            case NATURAL:
                value = return_names ? PyUnicode_FromString(ARG_TYPE_NATURAL) : PyLong_FromUnsignedLong(args[i].n);
                break;
            case INTEGER:
                value = return_names ? PyUnicode_FromString(ARG_TYPE_INTEGER) : PyLong_FromLong(args[i].i);
                break;
            case REAL:
                value = return_names ? PyUnicode_FromString(ARG_TYPE_REAL) : PyFloat_FromDouble(args[i].r);
                break;
            case STRING:
                value = return_names ? PyUnicode_FromString(ARG_TYPE_STRING) : PyUnicode_FromString(args[i].s);
                break;
        }
        if (!value) {
            Py_DECREF(dict);
            return NULL;
        }
        if (PyDict_SetItemString(dict, args[i].name, value) < 0) {
            Py_DECREF(value);
            Py_DECREF(dict);
            return NULL;
        }
        Py_DECREF(value);  // Decrement after successful addition
    }
    return dict;
}
