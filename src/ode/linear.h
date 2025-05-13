#ifndef LINEAR_H
#define LINEAR_H

#include "ds.h"

ode_t ode_linear_create(N n, R t, const R *x, const R *params);

#endif
