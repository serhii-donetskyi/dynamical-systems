#ifndef PY_ODE_H
#define PY_ODE_H

#include "core.h"
#include "structmember.h"
#include <Python.h>

// Python wrapper for ode_output_t
typedef struct {
  PyObject_HEAD ode_output_t *output; // Pointer to the C ode_output_t struct
  void *handle;                       // Pointer to the C handle
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
