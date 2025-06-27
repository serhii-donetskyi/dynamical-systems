#include "core.h"

static const char* validate(const argument_t *restrict args) {
    if (args[0].i <= 0) return "n must be positive";
    return 0;
}

static void fn(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const argument_t *restrict args) {
    (void) t;
    I n = args[0].i;
    for (I i = 0; i < n; i++) {
        dxdt[i] = 0;
        I k = i * n;
        for (I j = 0; j < n; j++) {
            dxdt[i] += p[k + j] * x[j];
        }
    }
}

static I x_size(const argument_t* args) {
    return args[0].i;
}

static I p_size(const argument_t* args) {
    return args[0].i * args[0].i;
}

ode_output_t ode_output = {
    .name = "linear",
    .args = (argument_t[]) {
        {
            .name = "n",
            .type = INTEGER,
            .i = 2
        },{
            .name = 0,
            .type = 0,
            .r = 0,
        }
    },
    .fn = fn,
    .x_size = x_size,
    .p_size = p_size,
    .validate = validate,
};

