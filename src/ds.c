#include "ds.h"
#include <stdlib.h>


// ODE
void ode_free(const ode_t *ode) {
    free((void*)(ode->x));
    free((void*)(ode->params));
}


// Solver
void solver_free(const solver_t *solver) {
    free((void*)(solver->params));
    free((void*)(solver->data));
}
