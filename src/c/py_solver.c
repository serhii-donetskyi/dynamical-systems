#include "py_solver.h"
#include "py_common.h"
#include "py_ode.h"
#include "dynlib.h"
#include <stdlib.h>
#include <string.h>

// SolverObjectPy implementation
static PyObject *SolverObjectPy_new(PyTypeObject *type, PyObject *args,
                                    PyObject *kwds) {
  (void)args;
  (void)kwds;
  SolverObjectPy *self = (SolverObjectPy *)type->tp_alloc(type, 0);
  if (!self)
    return NULL;
  self->factory = NULL;
  self->solver = NULL;
  return (PyObject *)self;
}

static int SolverObjectPy_init(SolverObjectPy *self, PyObject *args,
                               PyObject *kwds) {
  (void)self;
  (void)args;
  (void)kwds;
  PyErr_SetString(PyExc_NotImplementedError,
                  "Direct Solver() construction is not supported. Use a "
                  "factory class instead.");
  return -1;
}

static void SolverObjectPy_dealloc(SolverObjectPy *self) {
  if (self->solver) {
    PyMem_Free((void *)self->solver);
    self->solver = NULL;
  }
  if (self->factory)
    Py_DECREF(self->factory);
  Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the factory name
static SolverFactoryObjectPy *
SolverObjectPy_get_factory(SolverObjectPy *self, PyObject *Py_UNUSED(ignored)) {
  if (!self->factory) {
    PyErr_SetString(PyExc_RuntimeError, "Name not set");
    return NULL;
  }
  Py_INCREF(self->factory); // Return new reference
  return self->factory;
}

static PyObject *SolverObjectPy_get_arguments(SolverObjectPy *self,
                                              PyObject *Py_UNUSED(ignored)) {
  if (!self->solver) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid solver");
    return NULL;
  }
  return py_get_list_from_args(self->solver->args, 1);
}

// SolverFactoryObjectPy implementation
static PyObject *SolverFactoryObjectPy_new(PyTypeObject *type, PyObject *args,
                                           PyObject *kwds) {
  (void)args;
  (void)kwds;
  SolverFactoryObjectPy *self =
      (SolverFactoryObjectPy *)type->tp_alloc(type, 0);
  if (!self) {
    return NULL;
  }
  self->output = NULL;
  self->handle = NULL;
  return (PyObject *)self;
}

static int SolverFactoryObjectPy_init(SolverFactoryObjectPy *self,
                                      PyObject *args, PyObject *kwds) {
  char *kwlist[] = {"libpath", NULL};
  const char *libpath = NULL;
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "s", kwlist, &libpath)) {
    return -1;
  }
  dynlib_handle_t handle = dynlib_open(libpath);
  if (!handle) {
    PyErr_SetString(PyExc_RuntimeError, dynlib_error());
    return -1;
  }
  solver_output_t *output = (solver_output_t *)dynlib_sym(handle, "solver_output");
  if (!output) {
    PyErr_SetString(PyExc_RuntimeError, dynlib_error());
    dynlib_close(handle);
    return -1;
  }
  output->malloc = PyMem_Malloc;
  output->free = PyMem_Free;
  self->output = output;
  self->handle = handle;
  return 0;
}

static void SolverFactoryObjectPy_dealloc(SolverFactoryObjectPy *self) {
  if (self->handle) {
    dynlib_close(self->handle);
    self->handle = NULL;
  }
  self->output = NULL;
  Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyObject *SolverObjectPy_set_data(SolverObjectPy *self, PyObject *args,
                                         PyObject *kwargs) {
  if (!self->solver) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid solver");
    return NULL;
  }
  char *kwlist[] = {"ode", NULL};
  OdeObjectPy *ode = NULL;
  if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O!", kwlist, &OdeTypePy,
                                   &ode)) {
    return NULL;
  }
  result_t result = self->solver->set_data(self->solver, ode->ode);
  if (result.type == FAILURE) {
    PyErr_SetString(PyExc_RuntimeError, result.message);
    return NULL;
  }
  Py_RETURN_NONE;
}

// Factory method to create a SolverObjectPy
static PyObject *SolverFactoryObjectPy_create(SolverFactoryObjectPy *self,
                                              PyObject *args,
                                              PyObject *kwargs) {
  if (!self->output || !self->output->name || !self->output->args) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid factory state");
    return NULL;
  }
  argument_t *solver_args =
      py_copy_and_parse_args(args, kwargs, self->output->args);
  if (!solver_args)
    return NULL;

  result_t result = self->output->create(solver_args);
  PyMem_Free(solver_args); // solver_args are copied into the solver

  if (result.type == FAILURE) {
    PyErr_SetString(PyExc_RuntimeError, result.message);
    return NULL;
  }
  solver_t *solver = (solver_t *)result.data;
  SolverObjectPy *solver_obj =
      (SolverObjectPy *)SolverTypePy.tp_alloc(&SolverTypePy, 0);
  if (!solver || !solver_obj) {
    if (solver)
      self->output->destroy(solver);
    if (solver_obj)
      Py_DECREF(solver_obj);
    PyErr_SetString(PyExc_RuntimeError, "Failed to allocate memory");
    return NULL;
  }
  Py_INCREF(self);
  solver_obj->factory = self;
  solver_obj->solver = solver;
  return (PyObject *)solver_obj;
}

// get_argument_types() method: returns a dictionary mapping argument names to
// their types
static PyObject *
SolverFactoryObjectPy_get_argument_types(SolverFactoryObjectPy *self,
                                         PyObject *Py_UNUSED(ignored)) {
  if (!self->output || !self->output->args) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
    return NULL;
  }
  return py_get_list_from_args(self->output->args, 0);
}

// get_name() method: returns the factory name
static PyObject *SolverFactoryObjectPy_get_name(SolverFactoryObjectPy *self,
                                                PyObject *Py_UNUSED(ignored)) {
  if (!self->output || !self->output->name) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid output or name");
    return NULL;
  }
  return PyUnicode_FromString(self->output->name);
}

// Method tables
static PyMethodDef SolverObjectPy_methods[] = {
    {"get_factory", (PyCFunction)SolverObjectPy_get_factory, METH_NOARGS,
     "Return the factory of the Solver."},
    {"get_arguments", (PyCFunction)SolverObjectPy_get_arguments, METH_NOARGS,
     "Get arguments of the Solver."},
    {"set_data", (PyCFunction)(void (*)(void))SolverObjectPy_set_data,
     METH_VARARGS | METH_KEYWORDS, "Set data of the Solver."},
    {NULL, NULL, 0, NULL} /* Sentinel */
};

static PyMethodDef SolverFactoryObjectPy_methods[] = {
    {"create", (PyCFunction)(void (*)(void))SolverFactoryObjectPy_create,
     METH_VARARGS | METH_KEYWORDS, "Create a new Solver instance."},
    {"get_argument_types",
     (PyCFunction)SolverFactoryObjectPy_get_argument_types, METH_NOARGS,
     "Return a dictionary mapping argument names to their types."},
    {"get_name", (PyCFunction)SolverFactoryObjectPy_get_name, METH_NOARGS,
     "Return the name of the Solver factory."},
    {NULL, NULL, 0, NULL} /* Sentinel */
};

// Type objects
PyTypeObject SolverTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0).tp_name = "dynamical_systems.Solver",
    .tp_basicsize = sizeof(SolverObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = SolverObjectPy_new,
    .tp_init = (initproc)SolverObjectPy_init,
    .tp_dealloc = (destructor)SolverObjectPy_dealloc,
    .tp_methods = SolverObjectPy_methods,
    .tp_doc = "Solver object wrapping a C solver_t struct",
};

PyTypeObject SolverFactoryTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0).tp_name = "dynamical_systems.SolverFactory",
    .tp_basicsize = sizeof(SolverFactoryObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = SolverFactoryObjectPy_new,
    .tp_init = (initproc)SolverFactoryObjectPy_init,
    .tp_dealloc = (destructor)SolverFactoryObjectPy_dealloc,
    .tp_methods = SolverFactoryObjectPy_methods,
    .tp_doc = "SolverFactory object wrapping a C solver_output_t struct",
};
