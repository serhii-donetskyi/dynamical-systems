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
    if (!self) return NULL;
    return (PyObject *)self;
}

static int JobObjectPy_init(JobObjectPy *self, PyObject *args, PyObject *kwds) {
    (void)self;
    (void)args;
    (void)kwds;
    PyErr_SetString(PyExc_NotImplementedError, "Direct Job() construction is not supported. Use a factory class instead.");
    return -1;
}

static void JobObjectPy_dealloc(JobObjectPy *self) {
    if (self->args) {
        PyMem_Free(self->args);
        self->args = NULL;
    }
    if (self->factory) Py_DECREF(self->factory);
    self->factory = NULL;
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// run() method: executes the job with given ODE, solver, and arguments
static PyObject *JobObjectPy_run(JobObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->factory || !self->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid job state");
        return NULL;
    }

    OdeObjectPy *ode_obj = NULL;
    SolverObjectPy *solver_obj = NULL;

    char *kwlist[] = {"ode", "solver", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O!O!", kwlist, &OdeTypePy, &ode_obj, &SolverTypePy, &solver_obj)) {
        return NULL;
    }
    if (!ode_obj->ode || !solver_obj->solver) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ODE or solver");
        return NULL;
    }

    result_t result = solver_obj->solver->set_data(solver_obj->solver, ode_obj->ode);
    if (result.type == FAILURE) {
        PyErr_SetString(PyExc_RuntimeError, result.message);
        return NULL;
    }

    result = self->factory->output->fn(ode_obj->ode, solver_obj->solver, self->args);
    if (result.type == FAILURE) {
        PyErr_SetString(PyExc_RuntimeError, result.message);
        return NULL;
    }

    Py_RETURN_NONE;
}

static PyObject *JobObjectPy_get_arguments(JobObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->args) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid job");
        return NULL;
    }
    return py_get_list_from_args(self->args, 1);
}

static PyObject* JobObjectPy_get_factory(JobObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->factory) {
        PyErr_SetString(PyExc_RuntimeError, "Name not set");
        return NULL;
    }
    Py_INCREF(self->factory);
    return (PyObject *)self->factory;
}


// JobFactoryObjectPy implementation
static PyObject *JobFactoryObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    JobFactoryObjectPy *self = (JobFactoryObjectPy *)type->tp_alloc(type, 0);
    if (!self) {
        return NULL;
    }
    self->output = NULL;
    self->handle = NULL;
    return (PyObject *)self;
}

static int JobFactoryObjectPy_init(JobFactoryObjectPy *self, PyObject *args, PyObject *kwds) {
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
    output->malloc = PyMem_Malloc;
    output->free = PyMem_Free;
    self->output = output;
    self->handle = handle;
    return 0;
}

static void JobFactoryObjectPy_dealloc(JobFactoryObjectPy *self) {
    if (self->handle) {
        dlclose(self->handle);
        self->handle = NULL;
    }
    self->output = NULL;
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the job name
static PyObject *JobFactoryObjectPy_get_name(JobFactoryObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->name) {
        PyErr_SetString(PyExc_RuntimeError, "Name not set");
        return NULL;
    }
    return PyUnicode_FromString(self->output->name);
}

// get_argument_types() method: returns a dictionary mapping argument names to their types
static PyObject *JobFactoryObjectPy_get_argument_types(JobFactoryObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    return py_get_list_from_args(self->output->args, 0);
}

static PyObject *JobFactoryObjectPy_create(JobFactoryObjectPy *self, PyObject *args, PyObject *kwargs) {
    if (!self->output) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid job factory");
        return NULL;
    }
    argument_t *job_args = py_copy_and_parse_args(args, kwargs, self->output->args);
    if (!job_args) return NULL;

    JobObjectPy *job_obj = (JobObjectPy *)JobTypePy.tp_alloc(&JobTypePy, 0);
    if (!job_obj) {
        PyErr_SetString(PyExc_RuntimeError, "Failed to allocate job object");
        PyMem_Free(job_args);
        return NULL;
    }
    Py_INCREF(self);
    job_obj->factory = self;
    job_obj->args = job_args;
    return (PyObject *)job_obj;
}

// Method table
static PyMethodDef JobObjectPy_methods[] = {
    {"run", (PyCFunction)(void(*)(void))JobObjectPy_run, METH_VARARGS | METH_KEYWORDS, "Run the job with given ODE, solver, and arguments."},
    {"get_arguments", (PyCFunction)(void(*)(void))JobObjectPy_get_arguments, METH_NOARGS, "Return the arguments of the job."},
    {"get_factory", (PyCFunction)(void(*)(void))JobObjectPy_get_factory, METH_NOARGS, "Return the factory object."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

static PyMethodDef JobFactoryObjectPy_methods[] = {
    {"create", (PyCFunction)(void(*)(void))JobFactoryObjectPy_create, METH_VARARGS | METH_KEYWORDS, "Create a Job object."},
    {"get_name", (PyCFunction)JobFactoryObjectPy_get_name, METH_NOARGS, "Return the name of the Job."},
    {"get_argument_types", (PyCFunction)JobFactoryObjectPy_get_argument_types, METH_NOARGS, "Return a dictionary mapping argument names to their types."},
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

PyTypeObject JobFactoryTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.JobFactory",
    .tp_basicsize = sizeof(JobFactoryObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = JobFactoryObjectPy_new,
    .tp_init = (initproc)JobFactoryObjectPy_init,
    .tp_dealloc = (destructor)JobFactoryObjectPy_dealloc,
    .tp_methods = JobFactoryObjectPy_methods,
    .tp_doc = "Job factory object wrapping a C job_output_t struct",
};

