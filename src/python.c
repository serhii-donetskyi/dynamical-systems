#include "py_common.h"
#include "py_job.h"
#include "py_ode.h"
#include "py_solver.h"

// --- Method Table ---
static PyMethodDef dynamical_systems_methods[] = {
    {NULL, NULL, 0, NULL} /* Sentinel */
};

// --- Module Definition & Initialization ---
static PyModuleDef dynamical_systems_module_def = {
    PyModuleDef_HEAD_INIT,
    "_dynamical_systems",
    "Python interface for dynamical_systems C library ODE components.",
    -1,
    dynamical_systems_methods,
    NULL,
    NULL,
    NULL,
    NULL};

PyMODINIT_FUNC PyInit__dynamical_systems(void) {
  PyObject *m;

  if (PyType_Ready(&OdeTypePy) < 0)
    return NULL;
  if (PyType_Ready(&OdeFactoryTypePy) < 0)
    return NULL;
  if (PyType_Ready(&SolverTypePy) < 0)
    return NULL;
  if (PyType_Ready(&SolverFactoryTypePy) < 0)
    return NULL;
  if (PyType_Ready(&JobFactoryTypePy) < 0)
    return NULL;
  if (PyType_Ready(&JobTypePy) < 0)
    return NULL;

  m = PyModule_Create(&dynamical_systems_module_def);
  if (m == NULL)
    return NULL;

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
  if (PyModule_AddObject(m, "SolverFactory", (PyObject *)&SolverFactoryTypePy) <
      0) {
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
    Py_DECREF(&SolverFactoryTypePy);
    Py_DECREF(&SolverTypePy);
    Py_DECREF(&OdeFactoryTypePy);
    Py_DECREF(&OdeTypePy);
    Py_DECREF(m);
    return NULL;
  }

  Py_INCREF(&JobFactoryTypePy);
  if (PyModule_AddObject(m, "JobFactory", (PyObject *)&JobFactoryTypePy) < 0) {
    Py_DECREF(&JobFactoryTypePy);
    Py_DECREF(&JobTypePy);
    Py_DECREF(&SolverFactoryTypePy);
    Py_DECREF(&SolverTypePy);
    Py_DECREF(&OdeFactoryTypePy);
    Py_DECREF(&OdeTypePy);
    Py_DECREF(m);
    return NULL;
  }
  return m;
}
