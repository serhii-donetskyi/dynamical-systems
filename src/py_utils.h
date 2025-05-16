#ifndef PY_UTILS_H
#define PY_UTILS_H

#include <Python.h>
#include "core/common.h"

/**
 * @brief Converts a Python sequence (list, tuple) of numbers to a C array of R.
 *
 * Allocates memory for the output array using PyMem_Malloc. The caller is responsible
 * for freeing this memory using PyMem_Free.
 *
 * @param seq The Python sequence object.
 * @param seq_name A descriptive name for the sequence (e.g., "x0", "matrix_A") for error messages.
 * @return R* Pointer to the newly allocated C array of R, or NULL on failure (with Python error set).
 */
int pysequence_to_R_array(PyObject *seq, const char* seq_name, R* arr, Py_ssize_t max_len);

#endif // PY_UTILS_H
