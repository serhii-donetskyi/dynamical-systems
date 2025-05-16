#ifndef PY_SOLVER_H
#define PY_SOLVER_H

#include <Python.h>
#include "structmember.h"
#include "core/solver.h"

typedef struct {
    PyObject_HEAD
    solver_t *c_solver;
} SolverObjectPy;

extern PyTypeObject SolverTypePy;

PyObject* py_create_solver_rk4(PyObject *self_module, PyObject *args, PyObject *kwds);

#endif // PY_SOLVER_H
