#include "core.h"

N data_size(const ode_t *restrict ode) {
    return ode->x_size * 5;
}

void step(ode_t *restrict ode, solver_t *restrict solver) {
    const N n = ode->x_size;
    const R h = solver->args[0].r;

    #define t (ode->t)
    #define x (ode->x)
    #define p (ode->p)
    #define fn (ode->fn)
    #define args (ode->args)

    #define y (solver->data)
    #define k1 (y+n)
    #define k2 (k1+n)
    #define k3 (k2+n)
    #define k4 (k3+n)

    fn(t, x, k1, p, args);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k1[i] / 2;
    }
    fn(t + h / 2, y, k2, p, args);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k2[i] / 2;
    }
    fn(t + h / 2, y, k3, p, args);
    for (N i = 0; i < n; i++) {
        y[i] = x[i] + h * k3[i];
    }
    fn(t + h, y, k4, p, args);
    for (N i = 0; i < n; i++) {
        x[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) * h / 6;
    }
    t += h;

    #undef k4
    #undef k3
    #undef k2
    #undef k1
    #undef y

    #undef args
    #undef fn
    #undef p
    #undef x
    #undef t
}

solver_output_t solver_output = {
    .name = "rk4",
    .args = (argument_t[]) {
        {
            .name = "h",
            .type = REAL,
            .r = 0.01,
        },{
            .name = 0,
            .type = NATURAL,
            .n = 0,
        }
    },
    .data_size = data_size,
    .step = step,
};
