#include "core.h"
#include <stdlib.h>
#include <string.h>

static void fn(const ode_t *restrict self, R t, const R *restrict x, R *restrict dxdt) {
    (void) t;
    I n = self->args[0].i;
    for (I i = 0; i < n; i++) {
        dxdt[i] = 0;
        I k = i * n;
        for (I j = 0; j < n; j++) {
            dxdt[i] += self->p[k + j] * x[j];
        }
    }
}

static result_t create(const argument_t *restrict args);
static void destroy(ode_t* ode);

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
    .malloc = malloc,
    .free = free,
    .create = create,
    .destroy = destroy,
};

static result_t create(const argument_t *restrict args) {
    const I n = args[0].i;
    if (n <= 0 || n > 100) {
        return (result_t){.type = FAILURE, .message = "n must satisfy: 0 < n <= 100"};
    }

    const I x_size = n;
    const I p_size = n * n;

    ode_t *ode = ode_output.malloc(sizeof(ode_t));
    argument_t *ode_args = ode_output.malloc(sizeof(argument_t) * 2);
    R* x = ode_output.malloc(x_size * sizeof(R));
    R* p = ode_output.malloc(p_size * sizeof(R));
    if (!ode || !ode_args || !x || !p){
        if (ode) ode_output.free(ode);
        if (ode_args) ode_output.free(ode_args);
        if (x) ode_output.free(x);
        if (p) ode_output.free(p);
        return (result_t){
            .type = FAILURE,
            .message = "Failed to allocate memory"
        };
    }
    ode_t tmp = {
        .args = ode_args,
        .fn = fn,
        .x_size = x_size,
        .p_size = p_size,
        .x = x,
        .p = p,
    };
    memcpy(ode, &tmp, sizeof(ode_t));
    memcpy(ode_args, args, sizeof(argument_t) * 2);

    return (result_t){.type = SUCCESS, .data = (void *)ode};
}

static void destroy(ode_t *ode) {
    ode_output.free((void *)ode->args);
    ode_output.free((void *)ode->x);
    ode_output.free((void *)ode->p);
    ode_output.free((void *)ode);
}
