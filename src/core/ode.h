#ifndef ODE_H
#define ODE_H

#include "core/common.h"

typedef void (*ode_fn_t)(R t, const R *x, const R *p, R *dxdt);

typedef struct ode_t {
    N n;
    R t;
    R *x;
    R *p;
    ode_fn_t fn;
} ode_t;

void ode_linear(R t, const R *restrict x, const R *restrict p, R *restrict dxdt);

#endif // ODE_H 
