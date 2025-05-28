#ifndef ODE_H
#define ODE_H

typedef long I;
typedef unsigned long N;
typedef double R;

typedef union {
    N n;
    I i;
    R r;
} number;

_Static_assert(sizeof(number) == sizeof(N), "number and N must have the same size");
_Static_assert(sizeof(number) == sizeof(I), "number and I must have the same size");
_Static_assert(sizeof(number) == sizeof(R), "number and R must have the same size");

// ODE
typedef void (*ode_fn)(R t, const R *restrict x, R *restrict dxdt, const R *restrict p, const number *restrict consts);

typedef struct ode_t {
    const N x_size;
    const N p_size;
    R t;
    R *const x;
    R *const p;
    const number *const consts;
    const ode_fn fn;
} ode_t;

// ODE output
typedef struct argument_t {
    const char * const name;
    const enum {
        NATURAL = 0,
        INTEGER = 1,
        REAL = 2,
    } type;
    number value;
} argument_t;

typedef N (*ode_x_size_fn)(const argument_t* arguments);
typedef N (*ode_p_size_fn)(const argument_t* arguments);

typedef struct ode_output_t {
    const char *const name;
    argument_t *const arguments;
    const ode_fn fn;
    const ode_x_size_fn x_size;
    const ode_p_size_fn p_size;
} ode_output_t;

#endif // ODE_H 
