#include "py_solver.h"
#include "py_common.h"
#include <stdlib.h>
#include <dlfcn.h>  // For RTLD_LAZY
#include <string.h>

// SolverObjectPy implementation
static PyObject *SolverObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    SolverObjectPy *self = (SolverObjectPy *)type->tp_alloc(type, 0);
    if (!self) {
        return NULL;
    }
    self->name = NULL;  // Initialize to NULL
    self->solver = NULL;  // Initialize to NULL
    return (PyObject *)self;
}

static int SolverObjectPy_init(SolverObjectPy *self, PyObject *args, PyObject *kwds) {
    (void)self;
    (void)args;
    (void)kwds;
    PyErr_SetString(PyExc_NotImplementedError, "Direct Solver() construction is not supported. Use a factory class instead.");
    return -1;
}

static void SolverObjectPy_dealloc(SolverObjectPy *self) {
    if (self->solver) {
        if (self->solver->args) PyMem_Free((void *)self->solver->args);
        if (self->solver) PyMem_Free(self->solver);
        self->solver = NULL;
    }
    if (self->name) Py_DECREF(self->name);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the factory name
static PyObject *SolverObjectPy_get_name(SolverObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->name) {
        PyErr_SetString(PyExc_RuntimeError, "Name not set");
        return NULL;
    }
    Py_INCREF(self->name);  // Return new reference
    return self->name;
}

static PyObject *SolverObjectPy_get_arguments(SolverObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->solver) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid solver");
        return NULL;
    }
    I arg_size = 0;
    while (self->solver->args[arg_size].name) arg_size++;
    char types[arg_size + 1];
    const char* names[arg_size];
    const void* src[arg_size];
    for (I i = 0; i < arg_size; i++) {
        types[i] = (char)self->solver->args[i].type;
        names[i] = self->solver->args[i].name;
        src[i] = &self->solver->args[i].i;
    }
    types[arg_size] = '\0';
    
    return py_get_dict_from_args(types, names, src);
}

// SolverFactoryObjectPy implementation
static PyObject *SolverFactoryObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    SolverFactoryObjectPy *self = (SolverFactoryObjectPy *)type->tp_alloc(type, 0);
    if (!self) {
        return NULL;
    }
    self->output = NULL;
    self->handle = NULL;
    return (PyObject *)self;
}

static int SolverFactoryObjectPy_init(SolverFactoryObjectPy *self, PyObject *args, PyObject *kwds) {
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
    solver_output_t *output = (solver_output_t *)dlsym(handle, "solver_output");
    if (!output) {
        PyErr_SetString(PyExc_RuntimeError, dlerror());
        dlclose(handle);
        return -1;
    }
    self->output = output;
    self->handle = handle;
    return 0;
}

static void SolverFactoryObjectPy_dealloc(SolverFactoryObjectPy *self) {
    if (self->handle) {
        dlclose(self->handle);
        self->handle = NULL;
    }
    self->output = NULL;
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// Factory method to create a SolverObjectPy
static PyObject *SolverFactoryObjectPy_create(SolverFactoryObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->output || !self->output->name || !self->output->data_size || 
        !self->output->step || !self->output->args || !self->output->validate) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid factory state");
        return NULL;
    }

    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    // Allocate memory for arguments
    argument_t *_args = PyMem_Malloc(sizeof(argument_t) * (arg_size + 1));
    if (!_args) {
        PyErr_SetString(PyExc_MemoryError, "Failed to allocate memory for arguments");
        return NULL;
    }
    memcpy(_args, self->output->args, sizeof(argument_t) * (arg_size + 1));
    // Create type string and arrays
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

    // Create Solver object
    SolverObjectPy *py_solver = (SolverObjectPy *)SolverTypePy.tp_alloc(&SolverTypePy, 0);
    py_solver->name = PyUnicode_FromString(self->output->name);
    // Allocate and initialize Solver structure
    solver_t *solver = PyMem_Malloc(sizeof(solver_t));

    if (!py_solver || !solver || !_args) {
        PyErr_SetString(PyExc_RuntimeError, "Failed to create Solver");
        if (py_solver) Py_DECREF(py_solver);
        if (solver) PyMem_Free(solver);
        if (_args) PyMem_Free(_args);
        return NULL;
    }

    // Copy everything to solver
    solver_t tmp = {
        .args = _args,
        .data_size = self->output->data_size,
        .step = self->output->step,
    };
    memcpy(solver, &tmp, sizeof(solver_t));
    py_solver->solver = solver;

    return (PyObject *)py_solver;
}

// get_argument_types() method: returns a dictionary mapping argument names to their types
static PyObject *SolverFactoryObjectPy_get_argument_types(SolverFactoryObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
        return NULL;
    }
    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    char types[arg_size + 1];
    const char* names[arg_size];
    for (I i = 0; i < arg_size; i++) {
        types[i] = (char)self->output->args[i].type;
        names[i] = self->output->args[i].name;
    }
    types[arg_size] = '\0';
    
    return py_get_dict_from_args(types, names, NULL);
}

// Method tables
static PyMethodDef SolverObjectPy_methods[] = {
    {"get_name", (PyCFunction)SolverObjectPy_get_name, METH_NOARGS, "Return the name of the Solver."},
    {"get_arguments", (PyCFunction)SolverObjectPy_get_arguments, METH_NOARGS, "Get arguments of the Solver."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

static PyMethodDef SolverFactoryObjectPy_methods[] = {
    {"create", (PyCFunction)(void(*)(void))SolverFactoryObjectPy_create, METH_VARARGS | METH_KEYWORDS, "Create a new Solver instance."},
    {"get_argument_types", (PyCFunction)SolverFactoryObjectPy_get_argument_types, METH_NOARGS, "Return a dictionary mapping argument names to their types."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

// Type objects
PyTypeObject SolverTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.Solver",
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
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.SolverFactory",
    .tp_basicsize = sizeof(SolverFactoryObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = SolverFactoryObjectPy_new,
    .tp_init = (initproc)SolverFactoryObjectPy_init,
    .tp_dealloc = (destructor)SolverFactoryObjectPy_dealloc,
    .tp_methods = SolverFactoryObjectPy_methods,
    .tp_doc = "SolverFactory object wrapping a C solver_output_t struct",
};
