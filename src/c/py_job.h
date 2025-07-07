#ifndef PY_JOB_H
#define PY_JOB_H

#include "core.h"
#include "structmember.h"
#include "dynlib.h"
#include <Python.h>

typedef struct {
  PyObject_HEAD job_output_t *output; // Pointer to the C job_output_t struct
  dynlib_handle_t handle;             // Cross-platform handle
} JobFactoryObjectPy;

typedef struct {
  PyObject_HEAD JobFactoryObjectPy *factory;
  argument_t *args;
} JobObjectPy;

extern PyTypeObject JobFactoryTypePy;
extern PyTypeObject JobTypePy;

#endif // PY_JOB_H
