#ifndef PY_ODE_H
#define PY_ODE_H

#include <Python.h>
#include "structmember.h"
#include "core/ode.h"

typedef struct {
    PyObject_HEAD
    ode_t *c_ode;
} OdeObjectPy;

extern PyTypeObject OdeTypePy;

PyObject* py_create_ode_linear(PyObject *self_module, PyObject *args, PyObject *kwds);

#endif // PY_ODE_H 
