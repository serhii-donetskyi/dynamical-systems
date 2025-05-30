#ifndef CORE_H
#define CORE_H

typedef long I;
typedef unsigned long N;
typedef double R;

typedef struct argument_t {
    const char * const name;
    const enum {
        NATURAL = 0,
        INTEGER = 1,
        REAL = 2,
        STRING = 3,
    } type;
    union {
        N n;
        I i;
        R r;
        const char *s;
    };
} argument_t;

// ODE
typedef void (*ode_fn)(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const argument_t *restrict args);

typedef struct ode_t {
    const N x_size;
    const N p_size;
    R t;
    R *const x;
    R *const p;
    const argument_t *const args;
    const ode_fn fn;
} ode_t;

// ODE output
typedef N (*ode_x_size_fn)(const argument_t* args);
typedef N (*ode_p_size_fn)(const argument_t* args);

typedef struct ode_output_t {
    const char *const name;
    argument_t *const args;
    const ode_fn fn;
    const ode_x_size_fn x_size;
    const ode_p_size_fn p_size;
} ode_output_t;


// Solver
struct solver_t;

typedef N (*solver_data_size_fn)(const ode_t *restrict ode);
typedef void (*solver_step_fn)(ode_t *restrict ode, struct solver_t *restrict solver);

typedef struct solver_t {
    R* data;
    const argument_t *const args;
    const solver_data_size_fn data_size;
    const solver_step_fn step;
} solver_t;

// Solver output
typedef struct solver_output_t {
    const char *const name;
    argument_t *const args;
    const solver_data_size_fn data_size;
    const solver_step_fn step;
} solver_output_t;


// Job
typedef I (*job_fn)(ode_t *restrict ode, solver_t *restrict solver, const argument_t *restrict args);

typedef struct job_output_t {
    const char *const name;
    argument_t *const args;
    const job_fn fn;
} job_output_t;


#endif // CORE_H
