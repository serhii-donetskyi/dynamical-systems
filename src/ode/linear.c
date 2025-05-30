#include "core.h"

static void fn(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const argument_t *restrict args) {
    (void) t;
    N n = args[0].n;
    for (N i = 0; i < n; i++) {
        dxdt[i] = 0;
        N k = i * n;
        for (N j = 0; j < n; j++) {
            dxdt[i] += p[k + j] * x[j];
        }
    }
}

static N x_size(const argument_t* args) {
    return args[0].n;
}

static N p_size(const argument_t* args) {
    return args[0].n * args[0].n;
}

ode_output_t ode_output = {
    .name = "linear",
    .args = (argument_t[]) {
        {
            .name = "n",
            .type = NATURAL,
            .n = 2
        },{
            .name = 0,
            .type = REAL,
            .r = 0,
        }
    },
    .fn = fn,
    .x_size = x_size,
    .p_size = p_size,
};

