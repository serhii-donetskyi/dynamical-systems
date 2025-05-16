#include "py_job.h"
#include "py_ode.h"
#include "py_solver.h"

PyObject* py_phase_portrait(PyObject* self, PyObject* args, PyObject* kwds) {
    (void)self;
    char* kwlist[] = {"ode", "solver", "tend", "max_steps", NULL};
    OdeObjectPy* ode;
    SolverObjectPy* solver;
    R tend;
    N max_steps = 1000000;
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "O!O!d|I", kwlist, &OdeTypePy, &ode, &SolverTypePy, &solver, &tend, &max_steps)) {
        return NULL;
    }

    if (solver->c_solver->data == NULL) {
        solver->c_solver->data = (R *)PyMem_Malloc(solver->c_solver->data_size(ode->c_ode));
        if (solver->c_solver->data == NULL) {
            PyErr_NoMemory();
            return NULL;
        }
    } else {
        PyMem_Free(solver->c_solver->data);
        solver->c_solver->data = (R *)PyMem_Malloc(solver->c_solver->data_size(ode->c_ode));
        if (solver->c_solver->data == NULL) {
            PyErr_NoMemory();
            return NULL;
        }
    }

    for (N i = 0; i < max_steps; i++) {
        if (ode->c_ode->t >= tend) {
            break;
        }
        solver->c_solver->step(ode->c_ode, solver->c_solver);
    }

    PyMem_Free(solver->c_solver->data);
    solver->c_solver->data = NULL;

    Py_RETURN_NONE;
}

