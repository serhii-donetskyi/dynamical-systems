#include "py_ode.h"
#include "core/ode.h"
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
        if (self->ode->consts) PyMem_Free((void *)self->ode->consts);
        if (self->ode) PyMem_Free(self->ode);
        self->ode = NULL;
    }
    if (self->factory) {
        Py_DECREF(self->factory);
        self->factory = NULL;
    }
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// get_name() method: returns the factory name
static PyObject *OdeObjectPy_get_name(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode || !self->factory->output->name) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode or name");
        return NULL;
    }
    return PyUnicode_FromString(self->factory->output->name);
}

static PyObject *OdeObjectPy_get_arguments(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode || !self->factory) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode or arguments");
        return NULL;
    }
    argument_t *arguments = self->factory->output->arguments;
    PyObject *dict = PyDict_New();
    if (!dict) return NULL;
    for (N i = 0; arguments[i].name; ++i) {
        PyObject *value;
        switch (arguments[i].type) {
            case NATURAL:
                value = PyLong_FromLong(arguments[i].value.n);
                break;
            case INTEGER:
                value = PyLong_FromLong(arguments[i].value.i);
                break;
            case REAL:
                value = PyFloat_FromDouble(arguments[i].value.r);
                break;
            default:
                value = PyUnicode_FromString("UNKNOWN");
                break;
        }
        if (!value) {
            Py_DECREF(dict);
            return NULL;
        }
        PyDict_SetItemString(dict, arguments[i].name, value);
    }
    return dict;
}

static PyObject *OdeObjectPy_get_x_size(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode || !self->factory) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode or arguments");
        return NULL;
    }
    return PyLong_FromLong(self->ode->x_size);
}

static PyObject *OdeObjectPy_get_p_size(OdeObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->ode || !self->factory) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid ode or arguments");
        return NULL;
    }
    return PyLong_FromLong(self->ode->p_size);
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
    if (self->output) {
        dlclose(self->handle);
        self->output = NULL;
        self->handle = NULL;
    }
    Py_TYPE(self)->tp_free((PyObject *)self);
}

// Factory method to create an OdeObjectPy
static PyObject *OdeFactoryObjectPy_create_ode(PyObject *self, PyObject *args, PyObject *kwargs) {
    OdeFactoryObjectPy *factory = (OdeFactoryObjectPy *)self;
    if (!factory->output || !factory->output->x_size || !factory->output->p_size || !factory->output->fn) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid output or x_size or p_size or fn");
        return NULL;
    }

    // Count number of arguments
    N arg_size = 0;
    while (factory->output->arguments[arg_size++].name);
    arg_size--; // Adjust for the extra increment

    // Check if we have the correct number of arguments
    Py_ssize_t nargs = PyTuple_GET_SIZE(args);
    Py_ssize_t nkwargs = kwargs ? PyDict_Size(kwargs) : 0;
    
    if (nargs + nkwargs != (Py_ssize_t)arg_size) {
        PyErr_Format(PyExc_TypeError, "Expected %d arguments, got %zd", (int)arg_size, nargs + nkwargs);
        return NULL;
    }

    // Parse each argument
    N success = 1;
    for (N i = 0; i < arg_size; i++) {
        PyObject *arg = NULL;
        
        // Try to get argument from positional args first
        if ((Py_ssize_t)i < nargs) {
            arg = PyTuple_GET_ITEM(args, i);
        }
        // If not in positional args and we have keyword args, try to get from kwargs
        else if (kwargs) {
            arg = PyDict_GetItemString(kwargs, factory->output->arguments[i].name);
        }

        // If we still don't have an argument, it's an error
        if (!arg) {
            PyErr_Format(PyExc_TypeError, "Missing required argument '%s'", factory->output->arguments[i].name);
            success = 0;
            break;
        }

        switch (factory->output->arguments[i].type) {
            case NATURAL:
                if (!PyLong_Check(arg)) {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a non-negative integer", factory->output->arguments[i].name);
                    success = 0;
                    break;
                }
                factory->output->arguments[i].value.i = PyLong_AsLong(arg);
                if (PyErr_Occurred()) {
                    success = 0;
                    break;
                }
                if (factory->output->arguments[i].value.i < 0) {
                    PyErr_Format(PyExc_RuntimeError, "Argument '%s' must be a non-negative integer", factory->output->arguments[i].name);
                    success = 0;
                }
                break;
            case INTEGER:
                if (!PyLong_Check(arg)) {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be an integer", factory->output->arguments[i].name);
                    success = 0;
                    break;
                }
                factory->output->arguments[i].value.i = PyLong_AsLong(arg);
                if (PyErr_Occurred()) {
                    success = 0;
                    break;
                }
                break;
            case REAL:
                if (!PyFloat_Check(arg) && !PyLong_Check(arg)) {
                    PyErr_Format(PyExc_TypeError, "Argument '%s' must be a float or integer", factory->output->arguments[i].name);
                    success = 0;
                    break;
                }
                factory->output->arguments[i].value.r = PyFloat_AsDouble(arg);
                if (PyErr_Occurred()) {
                    success = 0;
                    break;
                }
                break;
            default:
                PyErr_SetString(PyExc_RuntimeError, "Invalid argument type");
                success = 0;
                break;
        }
        if (!success) {
            break;
        }
    }

    if (!success) {
        return NULL;
    }

    // Create ODE object
    OdeObjectPy *py_ode = (OdeObjectPy *)OdeTypePy.tp_alloc(&OdeTypePy, 0);

    // Allocate and initialize ODE structure
    ode_t *ode = PyMem_Malloc(sizeof(ode_t));
    N x_size = factory->output->x_size(factory->output->arguments);
    N p_size = factory->output->p_size(factory->output->arguments);
    R *x = x_size > 0 ? PyMem_Malloc(sizeof(R) * x_size) : 0;
    R *p = p_size > 0 ? PyMem_Malloc(sizeof(R) * p_size) : 0;
    number *consts = arg_size > 0 ? PyMem_Malloc(sizeof(number) * arg_size) : 0;

    if (!py_ode || !ode || !x_size || !x || (p_size > 0 && !p) || (arg_size > 0 && !consts)) {
        if (x_size == 0){
            PyErr_Format(PyExc_RuntimeError, "Failed to create ODE: x_size is 0");
        } else {
            PyErr_SetString(PyExc_RuntimeError, "Failed to create ODE");
        }
        if (py_ode) Py_DECREF(py_ode);
        if (ode) PyMem_Free(ode);
        if (x) PyMem_Free(x);
        if (p) PyMem_Free(p);
        if (consts) PyMem_Free(consts);
        return NULL;
    }

    // Copy argument values to consts
    for (N i = 0; i < arg_size; i++) {
        consts[i].n = factory->output->arguments[i].value.n;
    }
    ode_t tmp = {
        .x_size = x_size,
        .p_size = p_size,
        .fn = factory->output->fn,
        .x = x,
        .p = p,
        .consts = consts,
    };
    memcpy(ode, &tmp, sizeof(ode_t));
    py_ode->ode = ode;
    py_ode->factory = factory;
    Py_INCREF(factory);

    return (PyObject *)py_ode;
}

// get_argument_types() method: returns a dictionary mapping argument names to their types
static PyObject *OdeFactoryObjectPy_get_argument_types(OdeFactoryObjectPy *self, PyObject *Py_UNUSED(ignored)) {
    if (!self->output || !self->output->arguments) {
        PyErr_SetString(PyExc_RuntimeError, "Invalid output or arguments");
        return NULL;
    }
    argument_t *params = self->output->arguments;
    PyObject *dict = PyDict_New();
    if (!dict) return NULL;
    
    for (N i = 0; params[i].name; ++i) {
        PyObject *type_name;
        switch (params[i].type) {
            case NATURAL:
                type_name = PyUnicode_FromString("NATURAL");
                break;
            case INTEGER:
                type_name = PyUnicode_FromString("INTEGER");
                break;
            case REAL:
                type_name = PyUnicode_FromString("REAL");
                break;
            default:
                type_name = PyUnicode_FromString("UNKNOWN");
                break;
        }
        if (!type_name) {
            Py_DECREF(dict);
            return NULL;
        }
        if (PyDict_SetItemString(dict, params[i].name, type_name) < 0) {
            Py_DECREF(type_name);
            Py_DECREF(dict);
            return NULL;
        }
        Py_DECREF(type_name);
    }
    return dict;
}

// Method tables
static PyMethodDef OdeObjectPy_methods[] = {
    {"get_name", (PyCFunction)OdeObjectPy_get_name, METH_NOARGS, "Return the name of the ODE."},
    {"get_arguments", (PyCFunction)OdeObjectPy_get_arguments, METH_NOARGS, "Get arguments of the ODE."},
    {"get_x_size", (PyCFunction)OdeObjectPy_get_x_size, METH_NOARGS, "Get x_size of the ODE."},
    {"get_p_size", (PyCFunction)OdeObjectPy_get_p_size, METH_NOARGS, "Get p_size of the ODE."},
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

static PyMethodDef OdeFactoryObjectPy_methods[] = {
    {"create_ode", (PyCFunction)(void(*)(void))OdeFactoryObjectPy_create_ode, METH_VARARGS | METH_KEYWORDS, "Create a new ODE instance."},
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


