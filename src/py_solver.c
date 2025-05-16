#include "py_solver.h"
#include "Python.h"


static void SolverObjectPy_dealloc(SolverObjectPy *self) {
    if (self->c_solver) {
        if (self->c_solver->params) {
            PyMem_Free((void*)self->c_solver->params);
        }
        PyMem_Free((void*)self->c_solver);
        self->c_solver = NULL;
    }
    Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyObject* SolverObjectPy_new(PyTypeObject *type, PyObject *args, PyObject *kwds) {
    (void)args;
    (void)kwds;
    SolverObjectPy *self;
    self = (SolverObjectPy *)type->tp_alloc(type, 0);
    if (self != NULL) {
        self->c_solver = NULL;
    }
    return (PyObject *)self;
}

static int SolverObjectPy_init(SolverObjectPy *self, PyObject *args, PyObject *kwds) {
    // For now, do nothing. All construction should be done via the factory functions.
    (void)self;
    (void)args;
    (void)kwds;
    PyErr_SetString(PyExc_NotImplementedError, "Direct Solver() construction is not supported. Use a factory function.");
    return -1;
}

static PyMemberDef SolverObjectPy_members[] = {
    // You can expose fields here if needed
    {NULL, 0, 0, 0, NULL}  /* Sentinel */
};


PyTypeObject SolverTypePy = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "dynamical_systems.Solver",
    .tp_basicsize = sizeof(SolverObjectPy),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = SolverObjectPy_new,
    .tp_init = (initproc)SolverObjectPy_init,
    .tp_dealloc = (destructor)SolverObjectPy_dealloc,
    .tp_members = SolverObjectPy_members,
    // .tp_methods = ...,
    // .tp_getset = ...,
    .tp_doc = "Solver object wrapping a C solver_t struct",
};


PyObject* py_create_solver_rk4(PyObject *self_module, PyObject *args, PyObject *kwds) {
    (void)self_module;

    static char *kwlist[] = {"h", NULL};
    R h = 0.0;

    if (!PyArg_ParseTupleAndKeywords(args, kwds, "d", kwlist, &h)) {
        return NULL;
    }

    SolverObjectPy *solver_py_obj = (SolverObjectPy *)SolverTypePy.tp_alloc(&SolverTypePy, 0);
    if (!solver_py_obj) {
        // tp_alloc should set PyErr_NoMemory or similar
        return NULL;
    }
    // solver_py_obj->c_solver is initialized to NULL by SolverObjectPy_new

    solver_py_obj->c_solver = (solver_t *)PyMem_Malloc(sizeof(solver_t));
    if (!solver_py_obj->c_solver) {
        PyErr_NoMemory();
        Py_DECREF(solver_py_obj); // Free the Python wrapper
        return NULL;
    }

    R *params = (R *)PyMem_Malloc(sizeof(R)); // For h
    if (!params) {
        PyErr_NoMemory();
        PyMem_Free((void*)solver_py_obj->c_solver); // Free the c_solver struct
        Py_DECREF(solver_py_obj);          // Free the Python wrapper
        return NULL;
    }
    *params = h;
    solver_t solver = {
        .params = params,
        .step = solver_rk4,
        .data_size = solver_rk4_data_size,
        .data = NULL
    };
    memcpy(solver_py_obj->c_solver, &solver, sizeof(solver_t));
    
    return (PyObject *)solver_py_obj;
}
