#include "py_ode.h"
#include "py_common.h"
#include <stdlib.h>
#include <dlfcn.h>  // For RTLD_LAZY
#include <string.h>

// OdeObjectPy implementation
static PyObject *OdeObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    OdeObjectPy *self = (OdeObjectPy *)type->tp_alloc(type, 0);
    if (!self) {
        return NULL;
    }
    self->factory = NULL;  // Initialize to NULL
    self->ode = NULL;   // Initialize to NULL
    return (PyObject *)self;
}

static int OdeObjectPy_init(OdeObjectPy *self, PyObject *args, PyObject *kwds) {
    (void)self;
    (void)args;
    (void)kwds;
    PyErr_SetString(PyExc_NotImplementedError, "Direct Ode() construction is not supported. Use a factory class instead.");
    return -1;
}

static void OdeObjectPy_dealloc(OdeObjectPy *self) {
    if (self->ode) {
        if (self->ode->x) PyMem_Free(self->ode->x);
        if (self->ode->p) PyMem_Free(self->ode->p);
        if (self->ode->args) PyMem_Free((void *)self->ode->args);
        if (self->ode) PyMem_Free(self->ode);
        self->ode = NULL;
    }
    if (self->factory) Py_DECREF(self->factory);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the factory name
static OdeFactoryObjectPy *OdeObjectPy_get_factory(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->factory) {
        PyErr_SetString(PyExc_RuntimeError, "Name not set");
        return NULL;
    }
    Py_INCREF(self->factory);  // Return new reference
    return self->factory;
}

static PyObject *OdeObjectPy_get_arguments(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    I arg_size = 0;
    while (self->ode->args[arg_size].name) arg_size++;
    
    // Create type string and arrays
    char types[arg_size + 1];
    const char* names[arg_size];
    const void* src[arg_size];
    
    for (I i = 0; i < arg_size; i++) {
        types[i] = (char)self->ode->args[i].type;
        names[i] = self->ode->args[i].name;
        src[i] = &self->ode->args[i].i;
    }
    types[arg_size] = '\0';
    
    return py_get_dict_from_args(types, names, src);
}

static PyObject *OdeObjectPy_get_x_size(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    return PyLong_FromLong(self->ode->x_size);
}

static PyObject *OdeObjectPy_get_p_size(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    return PyLong_FromLong(self->ode->p_size);
}

static PyObject *OdeObjectPy_get_t(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    return PyFloat_FromDouble(self->ode->t);
}

static PyObject *OdeObjectPy_set_t(OdeObjectPy *self, PyObject *args, PyObject *kwargs) {
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
    Py_RETURN_NONE;
}

static PyObject *OdeObjectPy_get_x(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
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

static PyObject *OdeObjectPy_set_x(OdeObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    char *kwlist[] = {"index", "value", NULL};
    I index = 0;
    R value = 0;
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "kd", kwlist, &index, &value)) {
        return NULL;
    }
    if (index >= self->ode->x_size) {
        PyErr_Format(PyExc_IndexError, "Index %d must be between 0 and %d", index, self->ode->x_size - 1);
        return NULL;
    }
    self->ode->x[index] = value;
    Py_RETURN_NONE;
}

static PyObject *OdeObjectPy_get_p(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
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

static PyObject *OdeObjectPy_set_p(OdeObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->ode) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode");
        return NULL;
    }
    char *kwlist[] = {"index", "value", NULL};
    I index = 0;
    R value = 0;
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "kd", kwlist, &index, &value)) {
        return NULL;
    }
    if (index >= self->ode->p_size) {
        PyErr_Format(PyExc_IndexError, "Index %d must be between 0 and %d", index, self->ode->p_size - 1);
        return NULL;
    }
    self->ode->p[index] = value;
    Py_RETURN_NONE;
}

// OdeFactoryObjectPy implementation
static PyObject *OdeFactoryObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
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

static int OdeFactoryObjectPy_init(OdeFactoryObjectPy *self, PyObject *args, PyObject *kwds) {
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
static PyObject *OdeFactoryObjectPy_create(OdeFactoryObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->output || !self->output->name || !self->output->x_size || 
        !self->output->p_size || !self->output->fn || !self->output->args ||
        !self->output->validate) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid factory state");
        return NULL;
    }

    // Count number of arguments
    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    argument_t *_args = PyMem_Malloc(sizeof(argument_t) * (arg_size + 1));
    if (!_args) {
        PyErr_SetString(PyExc_MemoryError, "Failed to allocate memory for arguments");
        return NULL;
    }
    memcpy(_args, self->output->args, sizeof(argument_t) * (arg_size + 1));

    char types[arg_size + 1]; // +1 for null terminator
    const char* names[arg_size];
    void* dest[arg_size];
    for (I i = 0; i < arg_size; i++) {
        types[i] = (char)_args[i].type;
        names[i] = _args[i].name;
        dest[i] = &_args[i].i;
    }
    types[arg_size] = '\0';
    if (!py_parse_args(args, kwargs, types, names, dest)){
        return NULL;
    }
    
    const char* error = self->output->validate(_args);
    if (error) {
        PyErr_SetString(PyExc_RuntimeError, error);
        return NULL;
    }

    // Create ODE object
    OdeObjectPy *py_ode = (OdeObjectPy *)OdeTypePy.tp_alloc(&OdeTypePy, 0);
    py_ode->factory = self;
    Py_INCREF(self);
    // Allocate and initialize ODE structure
    ode_t *ode = PyMem_Malloc(sizeof(ode_t));
    I x_size = self->output->x_size(_args);
    I p_size = self->output->p_size(_args);
    R *x = PyMem_Malloc(sizeof(R) * x_size);
    R *p = PyMem_Malloc(sizeof(R) * p_size);

    if (!py_ode || !ode || !x_size || !x || (p_size > 0 && !p_size) || !arg_size) {
        if (x_size == 0){
            PyErr_Format(PyExc_RuntimeError, "Failed to create ODE: x_size is 0");
        } else {
            PyErr_SetString(PyExc_RuntimeError, "Failed to create ODE");
        }
        if (py_ode) Py_DECREF(py_ode);
        if (ode) PyMem_Free(ode);
        if (x) PyMem_Free(x);
        if (p) PyMem_Free(p);
        if (_args) PyMem_Free(_args);
        return NULL;
    }

    // Copy everything to ode
    ode_t tmp = {
        .x_size = x_size,
        .p_size = p_size,
        .fn = self->output->fn,
        .x = x,
        .p = p,
        .args = _args,
    };
    memcpy(ode, &tmp, sizeof(ode_t));
    py_ode->ode = ode;

    return (PyObject *)py_ode;
}

// get_argument_types() method: returns a dictionary mapping argument names to their types
static PyObject *OdeFactoryObjectPy_get_argument_types(OdeFactoryObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
        return NULL;
    }
    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    char types[arg_size + 1];
    const char *names[arg_size];
    for (I i = 0; i < arg_size; i++) {
        types[i] = (char)self->output->args[i].type;
        names[i] = self->output->args[i].name;
    }
    types[arg_size] = '\0';
    return py_get_dict_from_args(types, names, NULL);
}

// Method tables
static PyMethodDef OdeObjectPy_methods[] = {
    {"get_factory", (PyCFunction)OdeObjectPy_get_factory, METH_NOARGS, "Return the factory of the ODE."},
    {"get_arguments", (PyCFunction)OdeObjectPy_get_arguments, METH_NOARGS, "Get arguments of the ODE."},
    {"get_x_size", (PyCFunction)OdeObjectPy_get_x_size, METH_NOARGS, "Get x_size of the ODE."},
    {"get_p_size", (PyCFunction)OdeObjectPy_get_p_size, METH_NOARGS, "Get p_size of the ODE."},
    {"get_t", (PyCFunction)OdeObjectPy_get_t, METH_NOARGS, "Get t of the ODE."},
    {"set_t", (PyCFunction)(void(*)(void))OdeObjectPy_set_t, METH_VARARGS | METH_KEYWORDS, "Set t of the ODE."},
    {"get_x", (PyCFunction)OdeObjectPy_get_x, METH_NOARGS, "Get x of the ODE."},
    {"set_x", (PyCFunction)(void(*)(void))OdeObjectPy_set_x, METH_VARARGS | METH_KEYWORDS, "Set x of the ODE."},
    {"get_p", (PyCFunction)OdeObjectPy_get_p, METH_NOARGS, "Get p of the ODE."},
    {"set_p", (PyCFunction)(void(*)(void))OdeObjectPy_set_p, METH_VARARGS | METH_KEYWORDS, "Set p of the ODE."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

static PyMethodDef OdeFactoryObjectPy_methods[] = {
    {"create", (PyCFunction)(void(*)(void))OdeFactoryObjectPy_create, METH_VARARGS | METH_KEYWORDS, "Create a new ODE instance."},
    {"get_argument_types", (PyCFunction)OdeFactoryObjectPy_get_argument_types, METH_NOARGS, "Return a dictionary mapping argument names to their types."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

// Type objects
PyTypeObject OdeTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.Ode",
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
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.OdeFactory",
    .tp_basicsize = sizeof(OdeFactoryObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = OdeFactoryObjectPy_new,
    .tp_init = (initproc)OdeFactoryObjectPy_init,
    .tp_dealloc = (destructor)OdeFactoryObjectPy_dealloc,
    .tp_methods = OdeFactoryObjectPy_methods,
    .tp_doc = "OdeFactory object wrapping a C ode_factory_t struct",
};


