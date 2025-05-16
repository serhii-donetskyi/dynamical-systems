#include "core/solver.h"

N solver_rk4_data_size(const ode_t *restrict ode) {
    return sizeof(R) * (ode->n * 5);
}

void solver_rk4(ode_t *restrict ode, solver_t *restrict solver) {
    const N n = ode->n;
    const R h = solver->params[0];

    #define t (ode->t)
    #define x (ode->x)
    #define p (ode->p)
    #define fn (ode->fn)

    #define y (solver->data)
    #define k1 (y+n)
    #define k2 (k1+n)
    #define k3 (k2+n)
    #define k4 (k3+n)

    fn(t, x, p, k1);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k1[i] / 2;
    }
    fn(t + h / 2, y, p, k2);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k2[i] / 2;
    }
    fn(t + h / 2, y, p, k3);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k3[i];
    }
    fn(t + h, y, p, k4);
    for (N i = 0; i < n; i++) {
        x[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) * h / 6;
    }
    t += h;

    #undef k4
    #undef k3
    #undef k2
    #undef k1
    #undef y

    #undef fn
    #undef p
    #undef x
    #undef t
}
