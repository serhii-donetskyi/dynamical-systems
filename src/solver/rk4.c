#include "solver/rk4.h"
#include <stdlib.h>
#include <stdio.h>

void solver_rk4_fn(solver_t *solver) {
    const N n = solver->ode->n;
    const R h = solver->params[0];

    #define y (solver->data)
    #define k1 (y+n)
    #define k2 (k1+n)
    #define k3 (k2+n)
    #define k4 (k3+n)
    #define t (solver->ode->t)
    #define x (solver->ode->x)
    #define fn (solver->ode->fn)

    fn(t, x, solver->ode->params, k1);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h/2 * k1[i];
    }
    fn(t + h/2, y, solver->ode->params, k2);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h/2 * k2[i];
    }
    fn(t + h/2, y, solver->ode->params, k3);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k3[i];
    }
    fn(t + h, y, solver->ode->params, k4);

    for (N i = 0; i < n; i++) {
        x[i] += (k1[i] + 2*k2[i] + 2*k3[i] + k4[i]) * h/6;
    }
    t += h;

    #undef y
    #undef k1
    #undef k2
    #undef k3
    #undef k4
    #undef t
    #undef x
    #undef fn
}

solver_t solver_rk4_create(ode_t *ode, R h) {
    R* params = (R*)malloc(sizeof(R));
    *params = h;
    return (solver_t) {
        .ode = ode,
        .data = (R*)malloc(sizeof(R) * ode->n * 5),
        .params = params,
        .fn = solver_rk4_fn
    };
}

