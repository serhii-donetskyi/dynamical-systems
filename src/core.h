#ifndef CORE_H
#define CORE_H

typedef long I;
typedef double R;

typedef struct argument_t {
    const char * const name;
    const enum {
        INTEGER = 'i',
        REAL = 'r',
        STRING = 's',
    } type;
    union {
        I i;
        R r;
        const char *s;
    };
} argument_t;

typedef const char* (*argument_validate_fn)(const argument_t *restrict args);

// ODE
struct ode_t;
typedef void (*ode_fn)(const struct ode_t *restrict self, R t, const R *restrict x, R *restrict dxdt);

typedef struct ode_t {
    const I x_size;
    const I p_size;
    R t;
    R *const x;
    R *const p;
    const argument_t *const args;
    const ode_fn fn;
} ode_t;

// ODE output
typedef I (*ode_size_fn)(const argument_t *restrict args);

typedef struct ode_output_t {
    const char *const name;
    const argument_t *const args;
    const ode_fn fn;
    const ode_size_fn x_size;
    const ode_size_fn p_size;
    const argument_validate_fn validate;
} ode_output_t;


// Solver
struct solver_t;
typedef const char* (*solve_step_fn)(struct solver_t *restrict self, const ode_t *restrict ode, R *restrict t, R *restrict x, R t_end);

typedef struct solver_t {
    const argument_t *const args;
    const solve_step_fn step;
    void *data;
} solver_t;

// Solver output
typedef I (*solver_size_fn)(const argument_t *restrict args, const ode_t *restrict ode);

typedef struct solver_output_t {
    const char *const name;
    const argument_t *const args;
    const solve_step_fn step;
    const solver_size_fn size;
    const argument_validate_fn validate;
} solver_output_t;


// Job
typedef const char* (*job_fn)(ode_t *restrict ode, solver_t *restrict solver, const argument_t *restrict args);

typedef struct job_output_t {
    const char *const name;
    const argument_t *const args;
    const job_fn fn;
} job_output_t;


#endif // CORE_H
