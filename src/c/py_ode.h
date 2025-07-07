#ifndef PY_ODE_H
#define PY_ODE_H

#include "core.h"
#include "dynlib.h"
#include "structmember.h"
#include <Python.h>

// Python wrapper for ode_output_t
typedef struct {
  PyObject_HEAD ode_output_t *output; // Pointer to the C ode_output_t struct
  dynlib_handle_t handle;             // Cross-platform handle
} OdeFactoryObjectPy;

// Python wrapper for ode_t
typedef struct {
  PyObject_HEAD OdeFactoryObjectPy
      *factory; // Pointer to the C OdeFactoryObjectPy struct
  ode_t *ode;   // Pointer to the C ode_t struct
} OdeObjectPy;

extern PyTypeObject OdeTypePy;
extern PyTypeObject OdeFactoryTypePy;

#endif // PY_ODE_H
