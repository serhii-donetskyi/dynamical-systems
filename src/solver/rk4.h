#ifndef RK4_H
#define RK4_H

#include "ds.h"

solver_t solver_rk4_create(ode_t *ode, R h);

#endif
