#include "py_common.h"
#include "py_ode.h"
#include "py_solver.h"
#include "core.h"
#include <Python.h>

PyObject *py_parse_args(PyObject *args, PyObject *kwargs, const char *types, const char *const *names, void **dest) {
    if (!types || !names || !dest) {
        PyErr_SetString(PyExc_ValueError, "Invalid arguments to py_parse_args");
        return NULL;
    }

    Py_ssize_t nargs = PyTuple_GET_SIZE(args);
    for (Py_ssize_t i = 0; types[i]; i++) {
        if (!names[i]){
            PyErr_Format(PyExc_TypeError, "Invalid argument name at index %zd", i);
            return NULL;
        }
        
        PyObject *arg = NULL;
        
        // Try to get argument from positional args first
        if (i < nargs) {
            arg = PyTuple_GET_ITEM(args, i);
        }
        // If not in positional args and we have keyword args, try to get from kwargs
        else if (kwargs) {
            arg = PyDict_GetItemString(kwargs, names[i]);
        }

        // If we still don't have an argument, it's an error
        if (!arg) {
            PyErr_Format(PyExc_TypeError, "Missing required argument '%s'", names[i]);
            return NULL;
        }
        
        switch (types[i]) {
            case 'i':
                if (PyLong_Check(arg)) {
                    *((I *)dest[i]) = PyLong_AsLong(arg);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be an integer", names[i]);
                    return NULL;
                }
                break;
            case 'r':
                if (PyFloat_Check(arg)) {
                    *((R *)dest[i]) = PyFloat_AsDouble(arg);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a real number", names[i]);
                    return NULL;
                }
                break;
            case 's':
                if (PyUnicode_Check(arg)) {
                    *((const char **)dest[i]) = PyUnicode_AsUTF8(arg);
                } else {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a string", names[i]);
                    return NULL;
                }
                break;
            case 'O':
                if (!PyObject_IsInstance(arg, (PyObject *)&OdeTypePy)) {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be an Ode object", names[i]);
                    return NULL;
                }
                *((PyObject **)dest[i]) = arg;
                break;
            case 'S':
                if (!PyObject_IsInstance(arg, (PyObject *)&SolverTypePy)) {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a Solver object", names[i]);
                    return NULL;
                }
                *((PyObject **)dest[i]) = arg;
                break;
            default:
                PyErr_Format(PyExc_TypeError, "Invalid argument type '%c' for argument '%s'", types[i], names[i]);
                return NULL;
        }
        
        if (PyErr_Occurred()) return NULL;
    }
    Py_RETURN_NONE;
}

PyObject *py_get_dict_from_args(const char *types, const char *const *names, const void **src) {
    if (!types || !names) {
        PyErr_SetString(PyExc_ValueError, "Invalid arguments to py_get_dict_from_args");
        return NULL;
    }

    PyObject *dict = PyDict_New();
    if (!dict) return NULL;
    
    for (Py_ssize_t i = 0; types[i]; i++) {
        if (!names[i]){
            PyErr_Format(PyExc_TypeError, "Invalid argument name at index %zd", i);
            Py_DECREF(dict);
            return NULL;
        }
        PyObject *value = NULL;
        switch (types[i]) {
            case 'i':
                if (src) {
                    value = PyLong_FromLong(*((I *)src[i]));
                } else {
                    value = (PyObject *)&PyLong_Type;
                    Py_INCREF(value);
                }
                break;
            case 'r':
                if (src) {
                    value = PyFloat_FromDouble(*((R *)src[i]));
                } else {
                    value = (PyObject *)&PyFloat_Type;
                    Py_INCREF(value);
                }
                break;
            case 's':
                if (src) {
                    value = PyUnicode_FromString(*((char **)src[i]));
                } else {
                    value = (PyObject *)&PyUnicode_Type;
                    Py_INCREF(value);
                }
                break;
            case 'O':
                if (src) {
                    value = *((PyObject **)src[i]);
                    if (value) {
                        Py_INCREF(value);
                        if (!PyObject_IsInstance(value, (PyObject *)&OdeTypePy)) {
                            PyErr_Format(PyExc_TypeError, "Argument '%s' must be an Ode object", names[i]);
                            Py_DECREF(value);
                            value = NULL;
                        }
                    }
                } else {
                    value = (PyObject *)&OdeTypePy;
                    Py_INCREF(value);
                }
                break;
            case 'S':
                if (src) {
                    value = *((PyObject **)src[i]);
                    if (value) {
                        Py_INCREF(value);
                        if (!PyObject_IsInstance(value, (PyObject *)&SolverTypePy)) {
                            PyErr_Format(PyExc_TypeError, "Argument '%s' must be a Solver object", names[i]);
                            Py_DECREF(value);
                            value = NULL;
                        }
                    }
                } else {
                    value = (PyObject *)&SolverTypePy;
                    Py_INCREF(value);
                }
                break;
            default:
                PyErr_Format(PyExc_TypeError, "Invalid argument type '%c' for argument '%s'", types[i], names[i]);
                Py_DECREF(dict);
                return NULL;
        }
        if (!value) {
            Py_DECREF(dict);
            return NULL;
        }
        if (PyDict_SetItemString(dict, names[i], value) < 0) {
            Py_DECREF(value);
            Py_DECREF(dict);
            return NULL;
        }
        Py_DECREF(value);
    }
    return dict;
}
