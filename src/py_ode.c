#include "py_ode.h"
#include "py_utils.h"
#include <stdlib.h>

// Helper function to convert R array to Python list
static PyObject* R_array_to_PyList(const R *c_array, N array_size) {
    if (c_array == NULL && array_size > 0) {
        PyErr_SetString(PyExc_ValueError, "Input C array is NULL but size is non-zero.");
        return NULL;
    }
    PyObject *py_list = PyList_New((Py_ssize_t)array_size);
    if (py_list == NULL) {
        return NULL;
    }
    for (N i = 0; i < array_size; ++i) {
        PyObject *py_float = PyFloat_FromDouble((double)c_array[i]);
        if (py_float == NULL) {
            Py_DECREF(py_list);
            return NULL;
        }
        if (PyList_SetItem(py_list, (Py_ssize_t)i, py_float) < 0) { // Steals py_float ref
            // Py_DECREF(py_float); // Not needed as SetItem would have DECREF'd on failure if it took it
            Py_DECREF(py_list);
            return NULL;
        }
    }
    return py_list;
}

// --- OdeObjectPy properties (getset) ---

// Getter for 't'
static PyObject *OdeObjectPy_get_t(OdeObjectPy *self, void *closure) {
    (void)closure;
    if (!self->c_ode) {
        PyErr_SetString(PyExc_AttributeError, "C ODE object not initialized");
        return NULL;
    }
    return PyFloat_FromDouble(self->c_ode->t);
}

// Getter for 'n' (dimension, read-only)
static PyObject *OdeObjectPy_get_n(OdeObjectPy *self, void *closure) {
    (void)closure;
    if (!self->c_ode) {
        PyErr_SetString(PyExc_AttributeError, "C ODE object not initialized");
        return NULL;
    }
    return PyLong_FromSize_t(self->c_ode->n); // Assuming N is size_t or compatible
}

// Getter for 'x' (state vector, read-only copy)
static PyObject *OdeObjectPy_get_x(OdeObjectPy *self, void *closure) {
    (void)closure;
    if (!self->c_ode) {
        PyErr_SetString(PyExc_AttributeError, "C ODE object not initialized");
        return NULL;
    }
    if (!self->c_ode->x) {
        PyErr_SetString(PyExc_AttributeError, "'x' array is NULL in C ODE object");
        return NULL;
    }
    return R_array_to_PyList(self->c_ode->x, self->c_ode->n);
}

// Getter for 'p' (parameter vector/matrix, read-only copy)
// This will expose the full p vector including the first 'n' element.
// A more advanced version could return only the matrix part.
static PyObject *OdeObjectPy_get_p(OdeObjectPy *self, void *closure) {
    (void)closure;
    if (!self->c_ode) {
        PyErr_SetString(PyExc_AttributeError, "C ODE object not initialized");
        return NULL;
    }
    if (!self->c_ode->p) {
        PyErr_SetString(PyExc_AttributeError, "'p' array is NULL in C ODE object");
        return NULL;
    }
    // Size of p is n*n for the matrix, plus 1 for the stored 'n'
    N p_total_len = (self->c_ode->n * self->c_ode->n) + 1;
    return R_array_to_PyList(self->c_ode->p, p_total_len);
}

static PyGetSetDef OdeObjectPy_getsetters[] = {
    {"t", (getter)OdeObjectPy_get_t, NULL, "time attribute (float)", NULL},
    {"n", (getter)OdeObjectPy_get_n, NULL, "dimension of state vector (int, read-only)", NULL},
    {"x", (getter)OdeObjectPy_get_x, NULL, "state vector (list of floats, read-only copy)", NULL},
    {"p", (getter)OdeObjectPy_get_p, NULL, "parameter vector/matrix (list of floats, read-only copy, includes leading n)", NULL},
    {NULL, NULL, NULL, NULL, NULL}  /* Sentinel */
};

// --- OdeObjectPy methods ---

static void OdeObjectPy_dealloc(OdeObjectPy *self) {
    if (self->c_ode) {
        if (self->c_ode->x) {
            PyMem_Free((void*)self->c_ode->x);
        }
        if (self->c_ode->p) {
            PyMem_Free((void*)self->c_ode->p);
        }
        PyMem_Free((void*)self->c_ode);
        self->c_ode = NULL;
    }
    Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyObject *OdeObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    OdeObjectPy *self = (OdeObjectPy *)type->tp_alloc(type, 0);
    if (self) {
        self->c_ode = NULL;
    }
    return (PyObject *)self;
}

static int OdeObjectPy_init(OdeObjectPy *self, PyObject *args, PyObject *kwds) {
    // For now, do nothing. All construction should be done via the factory functions.
    (void)self;
    (void)args;
    (void)kwds;
    PyErr_SetString(PyExc_NotImplementedError, "Direct Ode() construction is not supported. Use a factory function.");
    return -1;
}

static PyMemberDef OdeObjectPy_members[] = {
    // You can expose fields here if needed
    {NULL, 0, 0, 0, NULL}  /* Sentinel */
};

PyTypeObject OdeTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.Ode",
    .tp_basicsize = sizeof(OdeObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = OdeObjectPy_new,
    .tp_init = (initproc)OdeObjectPy_init,
    .tp_dealloc = (destructor)OdeObjectPy_dealloc,
    .tp_members = OdeObjectPy_members,
    .tp_getset = OdeObjectPy_getsetters, // Assign getsetters
    .tp_doc = "Ode object wrapping a C ode_t struct",
};

// --- Factory functions ---

PyObject* py_create_ode_linear(PyObject *self_module, PyObject *args, PyObject *kwds) {
    (void)self_module; // To indicate self_module is intentionally unused

    char *kwlist[] = {"t", "x", "p", NULL};
    R t = 0.0;
    PyObject *x_obj = NULL;
    PyObject *p_obj = NULL;

    if (!PyArg_ParseTupleAndKeywords(args, kwds, "dOO", kwlist, &t, &x_obj, &p_obj)) {
        return NULL;
    }

    // Optionally, check that they are sequences (lists, tuples, etc.)
    if (!PySequence_Check(x_obj) || !PySequence_Check(p_obj)) {
        PyErr_SetString(PyExc_TypeError, "Arguments 'x' and 'p' must be sequences (lists or tuples)");
        return NULL;
    }

    Py_ssize_t x_len = PySequence_Length(x_obj);
    Py_ssize_t p_len = PySequence_Length(p_obj);

    if (x_len < 0 || p_len < 0) { // PySequence_Length returns -1 on error
        // Error already set by PySequence_Length
        return NULL;
    }
    
    if (x_len == 0) {
        PyErr_SetString(PyExc_ValueError, "Argument 'x' cannot be an empty sequence.");
        return NULL;
    }

    if ((N)x_len * (N)x_len != (N)p_len) {
        PyErr_SetString(PyExc_ValueError, "Argument 'p' must have n^2 elements, where n is the number of elements in 'x'.");
        return NULL;
    }
    R* x = (R*)PyMem_Malloc(x_len * sizeof(R));
    R* p = (R*)PyMem_Malloc((p_len + 1) * sizeof(R));

    if (!x || !p) {
        PyErr_NoMemory();
        if (x) PyMem_Free(x);
        if (p) PyMem_Free(p);
        return NULL;
    }

    if (pysequence_to_R_array(x_obj, "x", x, x_len) < 0) { // pysequence_to_R_array returns -1 on error
        PyMem_Free(x);
        PyMem_Free(p);
        return NULL; // Error already set by pysequence_to_R_array
    }
    
    // Store n (dimension of x) as the first element of p
    // Ensure N can hold x_len. If N is uint, check x_len not too large.
    ((N*)p)[0] = (N)x_len; 
    
    // Populate p_arr + 1 with the contents of p_obj
    if (pysequence_to_R_array(p_obj, "p", p + 1, p_len) < 0) {
        PyMem_Free(x);
        PyMem_Free(p);
        return NULL; // Error already set by pysequence_to_R_array
    }

    OdeObjectPy *ode_obj = (OdeObjectPy *)OdeTypePy.tp_alloc(&OdeTypePy, 0);
    if (!ode_obj) { // tp_alloc sets error
        PyMem_Free(x);
        PyMem_Free(p);
        return NULL;
    }
    // ode_obj->c_ode is NULL from OdeObjectPy_new

    ode_obj->c_ode = (ode_t*)PyMem_Malloc(sizeof(ode_t));
    if (!ode_obj->c_ode) {
        PyErr_NoMemory();
        Py_DECREF(ode_obj); // DECREF the Python wrapper
        PyMem_Free(x);
        PyMem_Free(p);
        return NULL;
    }
    ode_t ode = {
        .t = t,
        .x = x,
        .p = p,
        .n = (N)x_len,
        .fn = ode_linear
    };
    memcpy(ode_obj->c_ode, &ode, sizeof(ode_t));

    return (PyObject *)ode_obj;
}



