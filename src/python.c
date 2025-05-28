#include "py_ode.h"

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

    // Add parameter type constants
    if (PyModule_AddStringConstant(m, "NATURAL", "NATURAL") < 0) {
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }
    if (PyModule_AddStringConstant(m, "INTEGER", "INTEGER") < 0) {
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }
    if (PyModule_AddStringConstant(m, "REAL", "REAL") < 0) {
        Py_DECREF(&OdeFactoryTypePy);
        Py_DECREF(&OdeTypePy);
        Py_DECREF(m);
        return NULL;
    }

    return m;
}
