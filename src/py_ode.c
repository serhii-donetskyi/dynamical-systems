#include "py_ode.h"
#include "py_common.h"
#include <dlfcn.h> // For RTLD_LAZY
#include <stdlib.h>
#include <string.h>

// OdeObjectPy implementation
static PyObject *OdeObjectPy_new(PyTypeObject *type, PyObject *args,
                                 PyObject *kwds) {
  (void)args;
  (void)kwds;
  OdeObjectPy *self = (OdeObjectPy *)type->tp_alloc(type, 0);
  if (!self) {
    return NULL;
  }
  self->factory = NULL; // Initialize to NULL
  self->ode = NULL;     // Initialize to NULL
  return (PyObject *)self;
}

static int OdeObjectPy_init(OdeObjectPy *self, PyObject *args, PyObject *kwds) {
  (void)self;
  (void)args;
  (void)kwds;
  PyErr_SetString(PyExc_NotImplementedError,
                  "Direct Ode() construction is not supported. Use a factory "
                  "class instead.");
  return -1;
}

static void OdeObjectPy_dealloc(OdeObjectPy *self) {
  if (self->ode) {
    if (self->ode->x)
      PyMem_Free(self->ode->x);
    if (self->ode->p)
      PyMem_Free(self->ode->p);
    if (self->ode->args)
      PyMem_Free((void *)self->ode->args);
    if (self->ode)
      PyMem_Free(self->ode);
    self->ode = NULL;
  }
  if (self->factory)
    Py_DECREF(self->factory);
  Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the factory name
static OdeFactoryObjectPy *
OdeObjectPy_get_factory(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
  if (!self->factory) {
    PyErr_SetString(PyExc_RuntimeError, "Name not set");
    return NULL;
  }
  Py_INCREF(self->factory); // Return new reference
  return self->factory;
}

static PyObject *OdeObjectPy_get_arguments(OdeObjectPy *self,
                                           PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  return py_get_list_from_args(self->ode->args, 1);
}

static PyObject *OdeObjectPy_get_x_size(OdeObjectPy *self,
                                        PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  return PyLong_FromLong(self->ode->x_size);
}

static PyObject *OdeObjectPy_get_p_size(OdeObjectPy *self,
                                        PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  return PyLong_FromLong(self->ode->p_size);
}

static PyObject *OdeObjectPy_get_t(OdeObjectPy *self,
                                   PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  return PyFloat_FromDouble(self->ode->t);
}

static PyObject *OdeObjectPy_set_t(OdeObjectPy *self, PyObject *args,
                                   PyObject *kwargs) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  char *kwlist[] = {"value", NULL};
  R value = 0;
  if (!PyArg_ParseTupleAndKeywords(args, kwargs, "d", kwlist, &value)) {
    return NULL;
  }
  self->ode->t = value;
  Py_INCREF(self);
  return (PyObject *)self;
}

static PyObject *OdeObjectPy_get_x(OdeObjectPy *self,
                                   PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  PyObject *list = PyList_New(self->ode->x_size);
  for (I i = 0; i < self->ode->x_size; i++) {
    if (PyList_SetItem(list, i, PyFloat_FromDouble(self->ode->x[i])) < 0) {
      Py_DECREF(list);
      return NULL;
    }
  }
  return list;
}

static PyObject *OdeObjectPy_set_x(OdeObjectPy *self, PyObject *args,
                                   PyObject *kwargs) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  char *kwlist[] = {"value", NULL};
  PyObject *value = NULL;
  if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O", kwlist, &value)) {
    return NULL;
  }

  // Check if value is a sequence (list, tuple, etc.)
  if (!PySequence_Check(value)) {
    PyErr_SetString(PyExc_TypeError,
                    "Value must be a sequence (list, tuple, etc.)");
    return NULL;
  }

  // Get the length of the sequence
  Py_ssize_t seq_length = PySequence_Length(value);
  if (seq_length < 0) {
    return NULL; // Exception already set by PySequence_Length
  }

  // Check if the sequence length matches the expected x_size
  if (seq_length != self->ode->x_size) {
    PyErr_Format(PyExc_ValueError, "Sequence length must be %d, but got %zd",
                 self->ode->x_size, seq_length);
    return NULL;
  }

  // Validate all elements are numbers and convert them to doubles
  for (Py_ssize_t i = 0; i < seq_length; i++) {
    PyObject *item = PySequence_GetItem(value, i);
    if (!item)
      return NULL; // Exception already set

    R double_value = PyFloat_AsDouble(item);
    Py_DECREF(item);

    if (PyErr_Occurred()) {
      PyErr_Format(PyExc_ValueError,
                   "Element at index %zd cannot be converted to float", i);
      return NULL;
    }
    self->ode->x[i] = double_value;
  }

  Py_INCREF(self);
  return (PyObject *)self;
}

static PyObject *OdeObjectPy_get_p(OdeObjectPy *self,
                                   PyObject *Py_UNUSED(ignored)) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  PyObject *list = PyList_New(self->ode->p_size);
  for (I i = 0; i < self->ode->p_size; i++) {
    if (PyList_SetItem(list, i, PyFloat_FromDouble(self->ode->p[i])) < 0) {
      Py_DECREF(list);
      return NULL;
    }
  }
  return list;
}

static PyObject *OdeObjectPy_set_p(OdeObjectPy *self, PyObject *args,
                                   PyObject *kwargs) {
  if (!self->ode) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
    return NULL;
  }
  char *kwlist[] = {"value", NULL};
  PyObject *value = NULL;
  if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O", kwlist, &value)) {
    return NULL;
  }

  // Check if value is a sequence (list, tuple, etc.)
  if (!PySequence_Check(value)) {
    PyErr_SetString(PyExc_TypeError,
                    "Value must be a sequence (list, tuple, etc.)");
    return NULL;
  }

  // Get the length of the sequence
  Py_ssize_t seq_length = PySequence_Length(value);
  if (seq_length < 0) {
    return NULL; // Exception already set by PySequence_Length
  }

  // Check if the sequence length matches the expected p_size
  if (seq_length != self->ode->p_size) {
    PyErr_Format(PyExc_ValueError, "Sequence length must be %d, but got %zd",
                 self->ode->p_size, seq_length);
    return NULL;
  }

  // Validate all elements are numbers and convert them to doubles
  for (Py_ssize_t i = 0; i < seq_length; i++) {
    PyObject *item = PySequence_GetItem(value, i);
    if (!item) {
      return NULL; // Exception already set
    }

    // Convert to double
    R double_value = PyFloat_AsDouble(item);
    Py_DECREF(item);

    if (PyErr_Occurred()) {
      // PyFloat_AsDouble failed, but let's provide a clearer error
      PyErr_Format(PyExc_ValueError,
                   "Element at index %zd cannot be converted to float", i);
      return NULL;
    }
    self->ode->p[i] = double_value;
  }

  Py_INCREF(self);
  return (PyObject *)self;
}

// OdeFactoryObjectPy implementation
static PyObject *OdeFactoryObjectPy_new(PyTypeObject *type, PyObject *args,
                                        PyObject *kwds) {
  (void)args;
  (void)kwds;
  OdeFactoryObjectPy *self = (OdeFactoryObjectPy *)type->tp_alloc(type, 0);
  if (!self) {
    return NULL;
  }
  self->output = NULL;
  self->handle = NULL;
  return (PyObject *)self;
}

static int OdeFactoryObjectPy_init(OdeFactoryObjectPy *self, PyObject *args,
                                   PyObject *kwds) {
  char *kwlist[] = {"libpath", NULL};
  const char *libpath = NULL;
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "s", kwlist, &libpath)) {
    return -1;
  }
  void *handle = dlopen(libpath, RTLD_LAZY);
  if (!handle) {
    PyErr_SetString(PyExc_RuntimeError, dlerror());
    return -1;
  }
  ode_output_t *output = (ode_output_t *)dlsym(handle, "ode_output");
  if (!output) {
    PyErr_SetString(PyExc_RuntimeError, dlerror());
    dlclose(handle);
    return -1;
  }
  output->malloc = PyMem_Malloc;
  output->free = PyMem_Free;
  self->output = output;
  self->handle = handle;
  return 0;
}

static void OdeFactoryObjectPy_dealloc(OdeFactoryObjectPy *self) {
  if (self->handle) {
    dlclose(self->handle);
    self->handle = NULL;
  }
  self->output = NULL;
  Py_TYPE(self)->tp_free((PyObject *)self);
}

// Factory method to create an OdeObjectPy
static PyObject *OdeFactoryObjectPy_create(OdeFactoryObjectPy *self,
                                           PyObject *args, PyObject *kwargs) {
  if (!self->output || !self->output->name || !self->output->args) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid factory state");
    return NULL;
  }

  argument_t *ode_args =
      py_copy_and_parse_args(args, kwargs, self->output->args);
  if (!ode_args)
    return NULL;

  result_t result = self->output->create(ode_args);
  PyMem_Free(ode_args); // ode_args are copied into the ode and no longer needed

  if (result.type == FAILURE) {
    PyErr_SetString(PyExc_RuntimeError, result.message);
    return NULL;
  }
  ode_t *ode = (ode_t *)result.data;
  OdeObjectPy *ode_obj = (OdeObjectPy *)OdeTypePy.tp_alloc(&OdeTypePy, 0);
  if (!ode_obj || !ode) {
    if (ode)
      self->output->destroy(ode);
    if (ode_obj)
      Py_DECREF(ode_obj);
    PyErr_SetString(PyExc_RuntimeError, "Failed to allocate memory");
    return NULL;
  }

  Py_INCREF(self);
  ode_obj->factory = self;
  ode_obj->ode = ode;
  return (PyObject *)ode_obj;
}

// get_argument_types() method: returns a dictionary mapping argument names to
// their types
static PyObject *
OdeFactoryObjectPy_get_argument_types(OdeFactoryObjectPy *self,
                                      PyObject *Py_UNUSED(ignored)) {
  if (!self->output || !self->output->args) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
    return NULL;
  }
  return py_get_list_from_args(self->output->args, 0);
}

// get_name() method: returns the factory name
static PyObject *OdeFactoryObjectPy_get_name(OdeFactoryObjectPy *self,
                                             PyObject *Py_UNUSED(ignored)) {
  if (!self->output || !self->output->name) {
    PyErr_SetString(PyExc_RuntimeError, "Invalid output or name");
    return NULL;
  }
  return PyUnicode_FromString(self->output->name);
}

// Method tables
static PyMethodDef OdeObjectPy_methods[] = {
    {"get_factory", (PyCFunction)OdeObjectPy_get_factory, METH_NOARGS,
     "Return the factory of the ODE."},
    {"get_arguments", (PyCFunction)OdeObjectPy_get_arguments, METH_NOARGS,
     "Get arguments of the ODE."},
    {"get_x_size", (PyCFunction)OdeObjectPy_get_x_size, METH_NOARGS,
     "Get x_size of the ODE."},
    {"get_p_size", (PyCFunction)OdeObjectPy_get_p_size, METH_NOARGS,
     "Get p_size of the ODE."},
    {"get_t", (PyCFunction)OdeObjectPy_get_t, METH_NOARGS, "Get t of the ODE."},
    {"set_t", (PyCFunction)(void (*)(void))OdeObjectPy_set_t,
     METH_VARARGS | METH_KEYWORDS, "Set t of the ODE."},
    {"get_x", (PyCFunction)OdeObjectPy_get_x, METH_NOARGS, "Get x of the ODE."},
    {"set_x", (PyCFunction)(void (*)(void))OdeObjectPy_set_x,
     METH_VARARGS | METH_KEYWORDS, "Set x of the ODE."},
    {"get_p", (PyCFunction)OdeObjectPy_get_p, METH_NOARGS, "Get p of the ODE."},
    {"set_p", (PyCFunction)(void (*)(void))OdeObjectPy_set_p,
     METH_VARARGS | METH_KEYWORDS, "Set p of the ODE."},
    {NULL, NULL, 0, NULL} /* Sentinel */
};

static PyMethodDef OdeFactoryObjectPy_methods[] = {
    {"create", (PyCFunction)(void (*)(void))OdeFactoryObjectPy_create,
     METH_VARARGS | METH_KEYWORDS, "Create a new ODE instance."},
    {"get_argument_types", (PyCFunction)OdeFactoryObjectPy_get_argument_types,
     METH_NOARGS, "Return a dictionary mapping argument names to their types."},
    {"get_name", (PyCFunction)OdeFactoryObjectPy_get_name, METH_NOARGS,
     "Return the name of the ODE factory."},
    {NULL, NULL, 0, NULL} /* Sentinel */
};

// Type objects
PyTypeObject OdeTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0).tp_name = "dynamical_systems.Ode",
    .tp_basicsize = sizeof(OdeObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = OdeObjectPy_new,
    .tp_init = (initproc)OdeObjectPy_init,
    .tp_dealloc = (destructor)OdeObjectPy_dealloc,
    .tp_methods = OdeObjectPy_methods,
    .tp_doc = "Ode object wrapping a C ode_t struct",
};

PyTypeObject OdeFactoryTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0).tp_name = "dynamical_systems.OdeFactory",
    .tp_basicsize = sizeof(OdeFactoryObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = OdeFactoryObjectPy_new,
    .tp_init = (initproc)OdeFactoryObjectPy_init,
    .tp_dealloc = (destructor)OdeFactoryObjectPy_dealloc,
    .tp_methods = OdeFactoryObjectPy_methods,
    .tp_doc = "OdeFactory object wrapping a C ode_factory_t struct",
};
