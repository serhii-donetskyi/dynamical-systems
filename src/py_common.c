#include "core.h"
#include "py_common.h"
#include "py_ode.h"
#include "py_solver.h"
#include <Python.h>
#include <string.h>

argument_t *py_copy_and_parse_args(PyObject *args, PyObject *kwargs, const argument_t* args_in) {
    I arg_size = 0;
    while (args_in[arg_size].name) arg_size++;
    argument_t *args_out = PyMem_Malloc(sizeof(argument_t) * (arg_size + 1));
    if (!args_out) return NULL;
    memcpy(args_out, args_in, sizeof(argument_t) * (arg_size + 1));

    Py_ssize_t nargs = PyTuple_GET_SIZE(args);
    for (Py_ssize_t i = 0; args_out[i].name; i++) {
        
        PyObject *value = NULL;
        
        // Try to get argument from positional args first
        if (i < nargs) {
            value = PyTuple_GET_ITEM(args, i);
        }
        // If not in positional args and we have keyword args, try to get from kwargs
        else if (kwargs) {
            value = PyDict_GetItemString(kwargs, args_out[i].name);
        }

        // If we still don't have an argument, it's an error
        if (!value) {
            PyErr_Format(PyExc_TypeError, "Missing required argument '%s'", args_out[i].name);
            return NULL;
        }
        
        switch (args_out[i].type) {
            case INTEGER:
                if (PyLong_Check(value)) {
                    args_out[i].i = PyLong_AsLong(value);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be an integer", args_out[i].name);
                    return NULL;
                }
                break;
            case REAL:
                if (PyFloat_Check(value)) {
                    args_out[i].r = PyFloat_AsDouble(value);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a real number", args_out[i].name);
                    return NULL;
                }
                break;
            case STRING:
                if (PyUnicode_Check(value)) {
                    args_out[i].s = PyUnicode_AsUTF8(value);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a string", args_out[i].name);
                    return NULL;
                }
                break;
            default:
                PyErr_Format(PyExc_TypeError, "Invalid argument type '%c' for argument '%s'", args_out[i].type, args_out[i].name);
                return NULL;
        }
        
        if (PyErr_Occurred()) return NULL;
    }
    return args_out;
}

PyObject *py_get_list_from_args(const argument_t* args_in, I return_values) {
    if (!args_in) {
        PyErr_SetString(PyExc_ValueError, "Invalid arguments to py_get_list_from_args");
        return NULL;
    }

    PyObject *list = PyList_New(0);
    if (!list) return NULL;
    
    for (Py_ssize_t i = 0; args_in[i].name; i++) {
        PyObject *value = NULL;
        switch (args_in[i].type) {
            case INTEGER:
                if (return_values) {
                    value = PyLong_FromLong(args_in[i].i);
                } else {
                    value = (PyObject *)&PyLong_Type;
                    Py_INCREF(value);
                }
                break;
            case REAL:
                if (return_values) {
                    value = PyFloat_FromDouble(args_in[i].r);
                } else {
                    value = (PyObject *)&PyFloat_Type;
                    Py_INCREF(value);
                }
                break;
            case STRING:
                if (return_values) {
                    value = PyUnicode_FromString(args_in[i].s);
                } else {
                    value = (PyObject *)&PyUnicode_Type;
                    Py_INCREF(value);
                }
                break;
            default:
                PyErr_Format(PyExc_TypeError, "Invalid argument type '%c' for argument '%s'", args_in[i].type, args_in[i].name);
                Py_DECREF(list);
                return NULL;
        }
        if (!value) {
            Py_DECREF(list);
            return NULL;
        }
        PyObject* dict = PyDict_New();
        PyObject* name = PyUnicode_FromString(args_in[i].name);
        if (!dict || !name) {
            if (dict) Py_DECREF(dict);
            if (name) Py_DECREF(name);
            Py_DECREF(value);
            Py_DECREF(list);
            return NULL;
        }
        if (
            PyList_Append(list, dict) < 0
            || PyDict_SetItemString(dict, "name", name) < 0
            || PyDict_SetItemString(dict, return_values ? "value" : "type", value) < 0
        ) {
            Py_DECREF(name);
            Py_DECREF(value);
            Py_DECREF(dict);
            Py_DECREF(list);
            return NULL;
        }
        Py_DECREF(name); // name is in dict now
        Py_DECREF(value); // value is in dict now
        Py_DECREF(dict); // dict is in list now
    }
    return list;
}
