#include "core/solver.h"

N solver_rk4_data_size(const ode_t *ode) {
    return sizeof(R) * (ode->n * 5);
}

void solver_rk4(ode_t *ode, solver_t *solver) {
    N n = ode->n;
    R t = ode->t;
    R *x = ode->x;
    R *p = ode->p;
    #define fn (ode->fn)

    R h = solver->params[0];
    R *y = solver->data;
    R *k1 = y + n;
    R *k2 = k1 + n;
    R *k3 = k2 + n;
    R *k4 = k3 + n;

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
    ode->t += h;

    #undef fn
}
