#include "core/ode.h"

static void fn(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const number *restrict consts) {
    (void) t;
    N n = consts[0].n;
    for (N i = 0; i < n; i++) {
        dxdt[i] = 0;
        N k = i * n;
        for (N j = 0; j < n; j++) {
            dxdt[i] += p[k + j] * x[j];
        }
    }
}
static N ode_x_size(const argument_t* parameters) {
    return parameters[0].value.n;
}
static N ode_p_size(const argument_t* parameters) {
    return parameters[0].value.n * parameters[0].value.n;
}

ode_output_t ode_output = {
    .name = "linear",
    .arguments = (argument_t[]) {
        {
            .name = "n",
            .type = NATURAL,
            .value.n = 2
        },{
            .name = 0,
            .type = REAL,
            .value.r = 0,
        }
    },
    .fn = fn,
    .x_size = ode_x_size,
    .p_size = ode_p_size,
};

