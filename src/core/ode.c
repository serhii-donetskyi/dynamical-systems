#include "core/ode.h"
#include <stdlib.h> // For malloc, free, NULL
#include <string.h> // For memcpy, memset
#include <math.h>   // For sin, cos in pendulum

void ode_linear(R t, const R *restrict x, const R *restrict p, R *restrict dxdt) {
    (void)t;
    const N n = ((N*)p)[0];
    p++;
    for (N i = 0; i < n; i++) {
        dxdt[i] = 0;
        N k = i * n;
        for (N j = 0; j < n; j++) {
            dxdt[i] += p[k + j] * x[j];
        }
    }
}
