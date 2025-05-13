#ifndef DS_H
#define DS_H

// Data types
typedef unsigned long N;
typedef double R;
_Static_assert(sizeof(N) == sizeof(R), "R and N must be the same size");

// ODE
typedef void (*ode_fn_t)(R t, const R *x, const R *params, R *dxdt);
typedef struct ode_t {
    const N n;
    R t;
    R *const x;
    const R *const params;
    const ode_fn_t fn;
} ode_t;
void ode_free(const ode_t *ode);


// Solver
struct solver_t;
typedef void (*solver_fn_t)(struct solver_t *solver);
typedef struct solver_t {
    ode_t *const ode;
    R *const data;
    const R *const params;
    const solver_fn_t fn;
} solver_t;
void solver_free(const solver_t *solver);

#endif
