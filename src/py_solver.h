#ifndef PY_SOLVER_H
#define PY_SOLVER_H

#include "core.h"
#include "structmember.h"
#include <Python.h>

// Solver
typedef struct {
  PyObject_HEAD solver_output_t *output;
  void *handle;
} SolverFactoryObjectPy;

typedef struct {
  PyObject_HEAD SolverFactoryObjectPy *factory;
  solver_t *solver;
} SolverObjectPy;

extern PyTypeObject SolverFactoryTypePy;
extern PyTypeObject SolverTypePy;

#endif // PY_SOLVER_H
