#ifndef CORE_H
#define CORE_H

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>

// Macro to select integer type matching pointer size
#if UINTPTR_MAX == 0xFFFFFFFF
// 32-bit system
typedef int I;
typedef float R;
#define PRI_I PRId32
#elif UINTPTR_MAX == 0xFFFFFFFFFFFFFFFF
// 64-bit system
typedef long long I;
typedef double R;
#define PRI_I PRId64
#else
#error "Unsupported system architecture"
#endif

// Verify our type selection worked
_Static_assert(sizeof(void *) == sizeof(I),
               "void* and I must have the same size");
_Static_assert(sizeof(I) == sizeof(R), "I and R must have the same size");

// Result
typedef struct result_t {
  enum {
    SUCCESS = 0,
    FAILURE = 1,
  } type;
  union {
    const char *message;
    void *data;
  };
} result_t;

// Argument
typedef struct argument_t {
  const char *const name;
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

// Allocators
typedef void *(*malloc_fn)(size_t size);
typedef void (*free_fn)(void *ptr);

// ODE
struct ode_t;
typedef void (*ode_fn)(const struct ode_t *restrict self, R t,
                       const R *restrict x, R *restrict dxdt);

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
typedef result_t (*ode_create_fn)(const argument_t *args);
typedef void (*ode_destroy_fn)(ode_t *ode);

typedef struct ode_output_t {
  const char *const name;
  const argument_t *const args;
  const ode_create_fn create;
  const ode_destroy_fn destroy;
  malloc_fn malloc;
  free_fn free;
} ode_output_t;

// Solver
struct solver_t;
typedef const char *(*solver_step_fn)(struct solver_t *restrict self,
                                      const ode_t *restrict ode, R *restrict t,
                                      R *restrict x, R t_end);
typedef result_t (*solver_set_data_fn)(struct solver_t *self, const ode_t *ode);

typedef struct solver_t {
  I n;
  void *data;
  const argument_t *const args;
  const solver_step_fn step;
  const solver_set_data_fn set_data;
} solver_t;

// Solver output
typedef result_t (*solver_create_fn)(const argument_t *args);
typedef void (*solver_destroy_fn)(solver_t *solver);

typedef struct solver_output_t {
  const char *const name;
  const argument_t *const args;
  const solver_create_fn create;
  const solver_destroy_fn destroy;
  malloc_fn malloc;
  free_fn free;
} solver_output_t;

// Job
typedef result_t (*job_fn)(ode_t *restrict ode, solver_t *restrict solver,
                           const argument_t *restrict args);

typedef struct job_output_t {
  const char *const name;
  const argument_t *const args;
  const job_fn fn;
  malloc_fn malloc;
  free_fn free;
} job_output_t;

#endif // CORE_H
