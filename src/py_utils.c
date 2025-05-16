#include "py_utils.h"
#include <Python.h> // Already included via py_utils.h but good for clarity

int pysequence_to_R_array(PyObject *seq, const char* seq_name, R* arr, Py_ssize_t max_len) {
    if (!PySequence_Check(seq)) {
        PyErr_Format(PyExc_TypeError, "%s must be a sequence (e.g., list or tuple).", seq_name);
        return -1;
    }

    Py_ssize_t len = PySequence_Length(seq);
    if (len > max_len) {
        len = max_len;
    }

    for (Py_ssize_t i = 0; i < len; ++i) {
        PyObject *item = PySequence_GetItem(seq, i);
        if (!item) {
            // PySequence_GetItem already sets an error
            return -1;
        }
        if (!PyFloat_Check(item) && !PyLong_Check(item)) {
            Py_DECREF(item);
            PyErr_Format(PyExc_TypeError, "%s: item at index %zd must be a number.", seq_name, i);
            return -1;
        }
        arr[i] = (R)PyFloat_AsDouble(item); // PyFloat_AsDouble handles PyLong too
        Py_DECREF(item);
        if (PyErr_Occurred()) { // PyFloat_AsDouble can fail (e.g. for too large long)
            return -1;
        }
    }

    return 0;
}

// Implementation of other py_utils functions would go here.
