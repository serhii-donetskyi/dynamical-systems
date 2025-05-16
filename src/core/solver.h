#ifndef SOLVER_H
#define SOLVER_H

#include "core/common.h"
#include "core/ode.h"

struct solver_t;

typedef N (*data_size_t)(const ode_t *ode);
typedef void (*solver_step_t)(ode_t *ode, struct solver_t *solver);

typedef struct solver_t {
    R *params;
    R *data;
    solver_step_t step;
    data_size_t data_size;
} solver_t;

N solver_rk4_data_size(const ode_t *restrict ode);
void solver_rk4(ode_t *restrict ode, solver_t *restrict solver);

#endif // SOLVER_H 
