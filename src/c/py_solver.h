#ifndef PY_SOLVER_H
#define PY_SOLVER_H

#include <Python.h>

#include "core.h"
#include "dynlib.h"
#include "structmember.h"

// Solver
typedef struct {
  PyObject_HEAD solver_output_t *output;
  dynlib_handle_t handle;
} SolverFactoryObjectPy;

typedef struct {
  PyObject_HEAD SolverFactoryObjectPy *factory;
  solver_t *solver;
} SolverObjectPy;

extern PyTypeObject SolverFactoryTypePy;
extern PyTypeObject SolverTypePy;

#endif // PY_SOLVER_H
