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
typedef void (*ode_fn)(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const argument_t *restrict args);

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
typedef I (*ode_x_size_fn)(const argument_t* args);
typedef I (*ode_p_size_fn)(const argument_t* args);

typedef struct ode_output_t {
    const char *const name;
    argument_t *const args;
    const ode_fn fn;
    const ode_x_size_fn x_size;
    const ode_p_size_fn p_size;
    const argument_validate_fn validate;
} ode_output_t;


// Solver
struct solver_t;

typedef I (*solver_data_size_fn)(const ode_t *restrict ode);
typedef void (*solver_step_fn)(ode_t *restrict ode, struct solver_t *restrict solver, R *restrict data);

typedef struct solver_t {
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
    const argument_validate_fn validate;
} solver_output_t;


// Job
typedef const char* (*job_fn)(ode_t *restrict ode, solver_t *restrict solver, R *restrict data, const argument_t *restrict args);

typedef struct job_output_t {
    const char *const name;
    argument_t *const args;
    const job_fn fn;
} job_output_t;


#endif // CORE_H
