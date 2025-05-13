#include "ode/linear.h"
#include <stdlib.h>
#include <stdio.h>

void ode_linear_fn(R t, const R *x, const R *params, R *dxdt) {
    (void) t;
    N n = ((N*)params)[0];
    params += 1;
    for (N i = 0; i < n; i++) {
        dxdt[i] = 0;
        N k = i*n;
        for (N j = 0; j < n; j++) {
            dxdt[i] += params[k + j] * x[j];
        }
    }
}

ode_t ode_linear_create(N n, R t, const R *x, const R *params) {
    R *x_copy = (R*)malloc(n * sizeof(R));
    for (N i = 0; i < n; i++) {
        x_copy[i] = x[i];
    }
    R *params_copy = (R*)malloc((n*n + 1) * sizeof(R));
    params_copy[0] = ((R*)(&n))[0];
    for (N i = 0; i < n*n; i++) {
        params_copy[i+1] = params[i];
    }
    return (ode_t) {
        .n = n,
        .t = t,
        .x = x_copy,
        .params = params_copy,
        .fn = ode_linear_fn
    };
}
