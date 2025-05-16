#include "py_ode.h"
#include "py_solver.h"
#include "py_utils.h"
#include "py_job.h"
// --- Method Table ---
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-function-type"
#endif
static PyMethodDef dynamical_systems_methods[] = {
    {"create_ode_linear", (PyCFunction)py_create_ode_linear, METH_VARARGS | METH_KEYWORDS, "Create a linear ODE object."},
    {"create_solver_rk4", (PyCFunction)py_create_solver_rk4, METH_VARARGS | METH_KEYWORDS, "Create a Runge-Kutta 4th order ODE solver object."},
    {"phase_portrait", (PyCFunction)py_phase_portrait, METH_VARARGS | METH_KEYWORDS, "Create a phase portrait of the ODE."},
    {NULL, NULL, 0, NULL}
};
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

// --- Module Definition & Initialization ---
static PyModuleDef dynamical_systems_module_def = {
    PyModuleDef_HEAD_INIT,
    "dynamical_systems",
    "Python interface for dynamical_systems C library ODE and Solver components.",
    -1,
    dynamical_systems_methods,
    NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC PyInit_dynamical_systems(void) {
    PyObject *m;

    if (PyType_Ready(&OdeTypePy) < 0) return NULL;
    if (PyType_Ready(&SolverTypePy) < 0) return NULL;

    m = PyModule_Create(&dynamical_systems_module_def);
    if (m == NULL) return NULL;

    Py_INCREF(&OdeTypePy);
    if (PyModule_AddObject(m, "Ode", (PyObject *)&OdeTypePy) < 0) {
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    Py_INCREF(&SolverTypePy);
    if (PyModule_AddObject(m, "Solver", (PyObject *)&SolverTypePy) < 0) {
        Py_DECREF(&SolverTypePy);
        Py_DECREF(&OdeTypePy); // Also decref OdeTypePy
        Py_DECREF(m);
        return NULL;
    }

    return m;
}
