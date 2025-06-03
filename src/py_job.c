#include "py_job.h"
#include "py_ode.h"
#include "py_solver.h"
#include "py_common.h"
#include <stdlib.h>
#include <dlfcn.h>  // For RTLD_LAZY
#include <string.h>

// JobObjectPy implementation
static PyObject *JobObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    JobObjectPy *self = (JobObjectPy *)type->tp_alloc(type, 0);
    if (!self) {
        return NULL;
    }
    self->output = NULL;
    self->handle = NULL;
    return (PyObject *)self;
}

static int JobObjectPy_init(JobObjectPy *self, PyObject *args, PyObject *kwds) {
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
    job_output_t *output = (job_output_t *)dlsym(handle, "job_output");
    if (!output) {
        PyErr_SetString(PyExc_RuntimeError, dlerror());
        dlclose(handle);
        return -1;
    }
    self->output = output;
    self->handle = handle;
    return 0;
}

static void JobObjectPy_dealloc(JobObjectPy *self) {
    if (self->handle) {
        dlclose(self->handle);
        self->handle = NULL;
    }
    self->output = NULL;
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the job name
static PyObject *JobObjectPy_get_name(JobObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->name) {
        PyErr_SetString(PyExc_RuntimeError, "Name not set");
        return NULL;
    }
    return PyUnicode_FromString(self->output->name);
}

// get_argument_types() method: returns a dictionary mapping argument names to their types
static PyObject *JobObjectPy_get_argument_types(JobObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
        return NULL;
    }
    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    
    // Create type string and names array (including ode and solver)
    char types[arg_size + 3];  // +2 for ode/solver, +1 for null terminator
    char const *names[arg_size + 2];
    
    types[0] = 'O';
    names[0] = "ode";
    types[1] = 'S';
    names[1] = "solver";
    
    for (I i = 0; i < arg_size; i++) {
        types[i+2] = (char)self->output->args[i].type;
        names[i+2] = self->output->args[i].name;
    }
    types[arg_size + 2] = '\0';
    
    return py_get_dict_from_args(types, names, NULL);
}

// run() method: executes the job with given ODE, solver, and arguments
static PyObject *JobObjectPy_run(JobObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->output || !self->output->fn || !self->output->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid job state");
        return NULL;
    }

    PyObject *ode_obj = NULL;
    PyObject *solver_obj = NULL;

    I arg_size = 0;
    while (self->output->args[arg_size].name) arg_size++;
    
    // Create type string and arrays (including ode and solver)
    char types[arg_size + 3];  // +2 for ode/solver, +1 for null terminator
    char const* names[arg_size + 2];
    void* dest[arg_size + 2];
    
    types[0] = 'O';
    names[0] = "ode";
    dest[0] = &ode_obj;
    types[1] = 'S';
    names[1] = "solver";
    dest[1] = &solver_obj;
    
    for (I i = 0; i < arg_size; i++) {
        types[i+2] = (char)self->output->args[i].type;
        names[i+2] = self->output->args[i].name;
        dest[i+2] = &self->output->args[i].i;
    }
    types[arg_size + 2] = '\0';
    
    if (!py_parse_args(args, kwargs, types, names, dest)){
        return NULL;
    }

    OdeObjectPy *ode_py = (OdeObjectPy *)ode_obj;
    SolverObjectPy *solver_py = (SolverObjectPy *)solver_obj;

    if (!ode_py->ode || !solver_py->solver) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ODE or Solver object");
        return NULL;
    }

    // Allocate data
    I data_size = solver_py->solver->data_size(ode_py->ode);
    R *data = PyMem_Malloc(sizeof(R) * data_size);
    if (!data) {
        PyErr_SetString(PyExc_RuntimeError, "Failed to allocate data");
        return NULL;
    }

    // Call the job function
    const char* error = self->output->fn(ode_py->ode, solver_py->solver, data, self->output->args);

    // Free data
    PyMem_Free(data);

    // Check for errors
    if (error) {
        PyErr_SetString(PyExc_RuntimeError, error);
        return NULL;
    }
    Py_RETURN_NONE;
}

// Method table
static PyMethodDef JobObjectPy_methods[] = {
    {"get_name", (PyCFunction)JobObjectPy_get_name, METH_NOARGS, "Return the name of the Job."},
    {"get_argument_types", (PyCFunction)JobObjectPy_get_argument_types, METH_NOARGS, "Return a dictionary mapping argument names to their types."},
    {"run", (PyCFunction)(void(*)(void))JobObjectPy_run, METH_VARARGS | METH_KEYWORDS, "Run the job with given ODE, solver, and arguments."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

// Type object
PyTypeObject JobTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.Job",
    .tp_basicsize = sizeof(JobObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = JobObjectPy_new,
    .tp_init = (initproc)JobObjectPy_init,
    .tp_dealloc = (destructor)JobObjectPy_dealloc,
    .tp_methods = JobObjectPy_methods,
    .tp_doc = "Job object wrapping a C job_output_t struct",
};


