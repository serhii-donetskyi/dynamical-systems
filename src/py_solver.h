#ifndef PY_SOLVER_H
#define PY_SOLVER_H

#include <Python.h>
#include "structmember.h"
#include "core.h"

// Solver
typedef struct {
    PyObject_HEAD
    solver_output_t *output;
    void* handle;
} SolverFactoryObjectPy;

typedef struct {
    PyObject_HEAD
    PyObject *name;
    solver_t *solver;
} SolverObjectPy;

extern PyTypeObject SolverFactoryTypePy;
extern PyTypeObject SolverTypePy;

#endif // PY_SOLVER_H
