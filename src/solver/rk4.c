#include "core.h"

#define MAX_STEPS 1000000000

static const char* validate(const argument_t *restrict args) {
    if (args[0].r <= 0 || args[0].r >= 0.5) return "h_max must satisfy: 0 < h_max < 0.5";
    return 0;
}

static I size(const argument_t *restrict args, const ode_t *restrict ode) {
    (void) args;
    return (ode->x_size * 5) * sizeof(R);
}

static const char* step(solver_t *restrict self, const ode_t *restrict ode, R *restrict t, R *restrict x, R t_end) {
    #define fn(t, x, dxdt) (ode->fn(ode, t, x, dxdt))

    const I n = ode->x_size;
    const R h_max = self->args[0].r;

    R* y = (R*)(self->data);
    R* k1 = y + n;
    R* k2 = k1 + n;
    R* k3 = k2 + n;
    R* k4 = k3 + n;
    const I sign = t_end > *t ? 1 : -1;
    I steps = 0;
    R h = sign * h_max;

    for (;steps < MAX_STEPS; steps++) {
        if (sign * (*t - t_end) > 0) break;
        if (sign * (*t + h - t_end) > 0) h = t_end - *t + sign * 1e-10;
        fn(*t, x, k1);
        for (I i = 0; i < n; i++) {
            y[i] = x[i] + h * k1[i] / 2;
        }
        fn(*t + h / 2, y, k2);
        for (I i = 0; i < n; i++) {
            y[i] = x[i] + h * k2[i] / 2;
        }
        fn(*t + h / 2, y, k3);
        for (I i = 0; i < n; i++) {
            y[i] = x[i] + h * k3[i];
        }
        fn(*t + h, y, k4);
        for (I i = 0; i < n; i++) {
            x[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) * h / 6;
        }
        *t += h;
    }
    if (steps >= MAX_STEPS) return "Solver has failed to finish in 1,000,000,000 steps";
    return 0;

    #undef fn
}

solver_output_t solver_output = {
    .name = "rk4",
    .args = (argument_t[]) {
        {
            .name = "h_max",
            .type = REAL,
            .r = 0.01,
        },{
            .name = 0,
            .type = 0,
            .i = 0,
        }
    },
    .size = size,
    .step = step,
    .validate = validate,
};
