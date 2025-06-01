#include "py_common.h"
#include "py_ode.h"
#include "py_solver.h"
#include "py_job.h"

// --- Method Table ---
static PyMethodDef dynamical_systems_methods[] = {
    {NULL, NULL, 0, NULL}  /* Sentinel */
};

// --- Module Definition & Initialization ---
static PyModuleDef dynamical_systems_module_def = {
    PyModuleDef_HEAD_INIT,
    "dynamical_systems",
    "Python interface for dynamical_systems C library ODE components.",
    -1,
    dynamical_systems_methods,
    NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC PyInit_dynamical_systems(void) {
    PyObject *m;

    if (PyType_Ready(&OdeTypePy) < 0) return NULL;
    if (PyType_Ready(&OdeFactoryTypePy) < 0) return NULL;
    if (PyType_Ready(&SolverTypePy) < 0) return NULL;
    if (PyType_Ready(&SolverFactoryTypePy) < 0) return NULL;
    if (PyType_Ready(&JobTypePy) < 0) return NULL;

    m = PyModule_Create(&dynamical_systems_module_def);
    if (m == NULL) return NULL;

    Py_INCREF(&OdeTypePy);
    if (PyModule_AddObject(m, "Ode", (PyObject *)&OdeTypePy) < 0) {
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    Py_INCREF(&OdeFactoryTypePy);
    if (PyModule_AddObject(m, "OdeFactory", (PyObject *)&OdeFactoryTypePy) < 0) {
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    Py_INCREF(&SolverTypePy);
    if (PyModule_AddObject(m, "Solver", (PyObject *)&SolverTypePy) < 0) {
        Py_DECREF(&SolverTypePy);
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    Py_INCREF(&SolverFactoryTypePy);
    if (PyModule_AddObject(m, "SolverFactory", (PyObject *)&SolverFactoryTypePy) < 0) {
        Py_DECREF(&SolverFactoryTypePy);
        Py_DECREF(&SolverTypePy);
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    Py_INCREF(&JobTypePy);
    if (PyModule_AddObject(m, "Job", (PyObject *)&JobTypePy) < 0) {
        Py_DECREF(&JobTypePy);
        Py_DECREF(&SolverTypePy);
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    // Add parameter type constants
    if (
        PyModule_AddStringConstant(m, ARG_TYPE_NATURAL, ARG_TYPE_NATURAL) < 0 ||
        PyModule_AddStringConstant(m, ARG_TYPE_INTEGER, ARG_TYPE_INTEGER) < 0 ||
        PyModule_AddStringConstant(m, ARG_TYPE_REAL, ARG_TYPE_REAL) < 0 ||
        PyModule_AddStringConstant(m, ARG_TYPE_STRING, ARG_TYPE_STRING) < 0
    ) {
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    return m;
}
