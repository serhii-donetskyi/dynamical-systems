#include "core.h"
#include <math.h>

#define C2 (2.0/10.0)
#define C3 (3.0/10.0)
#define C4 (8.0/10.0)
#define C5 (8.0/9.0)

#define A21 (2.0/10.0)

#define A31 (3.0/40.0)
#define A32 (9.0/40.0)

#define A41 (44.0/45.0)
#define A42 (-56.0/15.0)
#define A43 (32.0/9.0)

#define A51 (19372.0/6561.0)
#define A52 (-25360.0/2187.0)
#define A53 (64448.0/6561.0)
#define A54 (-212.0/729.0)

#define A61 (9017.0/3168.0)
#define A62 (-355.0/33.0)
#define A63 (46732.0/5247.0)
#define A64 (49.0/176.0)
#define A65 (-5103.0/18656.0)

#define A71 (35.0/384.0)
#define A73 (500.0/1113.0)
#define A74 (125.0/192.0)
#define A75 (-2187.0/6784.0)
#define A76 (11.0/84.0)

#define E1 (71.0/57600.0)
#define E3 (-71.0/16695.0)
#define E4 (71.0/1920.0)
#define E5 (-17253.0/339200.0)
#define E6 (22.0/525.0)
#define E7 (-1.0/40.0)

static const char* validate(const argument_t *restrict args) {
    if (args[0].r <= 0 || args[0].r >= 1) return "h_max must satisfy: 0 < h_max < 1";
    if (args[1].r <= 0 || args[1].r >= 1) return "eps must satisfy: 0 < eps < 1";
    return 0;
}

static I data_size(const ode_t *restrict ode) {
    return ode->x_size * 7 + 2;
}

static R max(R v1, R v2, R v3){
    return fmax(fmax(v1, v2), v3);
}

static void step(ode_t *restrict ode, solver_t *restrict solver, R *restrict data) {
    const I n = ode->x_size;
    const R h_max = solver->args[0].r;
    const R eps = solver->args[1].r;

    #define t (ode->t)
    #define x (ode->x)
    #define p (ode->p)
    #define fn (ode->fn)
    #define args (ode->args)

    #define h (data[0])
    #define reject (data[1])
    #define y (data+2)
    #define k1 (y+n)
    #define k2 (k1+n)
    #define k3 (k2+n)
    #define k4 (k3+n)
    #define k5 (k4+n)
    #define k6 (k5+n)

    if (!h) h = h_max;
    fn(t, x, k1, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * A21 * k1[i];
    }
    fn(t + h * C2, y, k2, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * (A31 * k1[i] + A32 * k2[i]);
    }
    fn(t + h * C3, y, k3, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * (A41 * k1[i] + A42 * k2[i] + A43 * k3[i]);
    }
    fn(t + h * C4, y, k4, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * (A51 * k1[i] + A52 * k2[i] + A53 * k3[i] + A54 * k4[i]);
    }
    fn(t + h * C5, y, k5, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * (A61 * k1[i] + A62 * k2[i] + A63 * k3[i] + A64 * k4[i] + A65 * k5[i]);
    }
    R tph = t + h;
    fn(tph, y, k6, p, args);
    for (I i = 0; i < n; i++) {
        y[i] = x[i] + h * (A71 * k1[i] + A73 * k3[i] + A74 * k4[i] + A75 * k5[i] + A76 * k6[i]);
    }
    fn(tph, y, k2, p, args);

    // Error estimation
    for (I i = 0; i < n; i++) {
        k4[i] = h * (E1 * k1[i] + E3 * k3[i] + E4 * k4[i] + E5 * k5[i] + E6 * k6[i] + E7 * k2[i]);
    }
    R err = 0;
    for (I i = 0; i < n; i++) {
        R rerr = k4[i] / max(1e-5, fabs(x[i]), fabs(y[i]));
        err += rerr * rerr;
    }
    err = sqrt(err / n);
    R fac = fmax(fmin(pow(eps / err, 0.2), 5.0), 0.2);
    R h_new = h * fac;

    if (err < eps) {
        t = tph;
        for (I i = 0; i < n; i++) {
            x[i] = y[i];
        }
        if (fabs(h_new) > h_max) h_new = h_max;
        if (reject) h_new = fmin(h_new, h_max);
        reject = 0;
    } else {
        if (h_new > h) h_new = h;
        if (h_new != h_new) h_new = 0.6 * h; // h_new is NaN
        if (reject) h_new *= 0.9;
        reject = 1;
    }
    h = h_new;

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
    .name = "dopri5",
    .args = (argument_t[]) {
        {.name = "h_max", .type = REAL, .r = 0.1},
        {.name = "eps", .type = REAL, .r = 1e-3},
        {.name = 0, .type = 0, .i = 0},
    },
    .data_size = data_size,
    .step = step,
    .validate = validate,
};

#undef C2
#undef C3
#undef C4
#undef C5

#undef A21

#undef A31
#undef A32

#undef A41
#undef A42
#undef A43

#undef A51
#undef A52
#undef A53
#undef A54

#undef A61
#undef A62
#undef A63
#undef A64
#undef A65

#undef A71
#undef A73
#undef A74
#undef A75
#undef A76

#undef E1
#undef E3
#undef E4
#undef E5
#undef E6
#undef E7
