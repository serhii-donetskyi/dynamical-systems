#ifndef PY_JOB_H
#define PY_JOB_H

#include "core.h"
#include <Python.h>
#include "structmember.h"

typedef struct {
    PyObject_HEAD
    job_output_t *output;  // Pointer to the C job_output_t struct
    void *handle;  // Pointer to the C handle
} JobFactoryObjectPy;

typedef struct {
    PyObject_HEAD
    JobFactoryObjectPy *factory;
    argument_t *args;
} JobObjectPy;

extern PyTypeObject JobFactoryTypePy;
extern PyTypeObject JobTypePy;

#endif // PY_JOB_H
