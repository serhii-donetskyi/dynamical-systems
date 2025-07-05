#include "core.h"
#include <stdlib.h>
#include <string.h>

#define MAX_STEPS 1000000000

static const char *step(solver_t *restrict self, const ode_t *restrict ode,
                        R *restrict t, R *restrict x, R t_end) {
#define fn(t, x, dxdt) (ode->fn(ode, t, x, dxdt))

  const I n = self->n;
  const R h_max = self->args[0].r;

  R *y = (R *)(self->data);
  R *k1 = y + n;
  R *k2 = k1 + n;
  R *k3 = k2 + n;
  R *k4 = k3 + n;
  const I sign = t_end > *t ? 1 : -1;
  R h = sign * h_max;

  I steps = 0;
  for (; steps < MAX_STEPS; steps++) {
    if (sign * (*t - t_end) >= 0)
      break;
    if (sign * (*t + h - t_end) >= 0)
      h = t_end - *t + sign * 1e-10;
    fn(*t, x, k1);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * k1[i] / 2;
    }
    fn(*t + h / 2, y, k2);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * k2[i] / 2;
    }
    fn(*t + h / 2, y, k3);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * k3[i];
    }
    fn(*t + h, y, k4);
    for (I i = 0; i < n; i++) {
      x[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) * h / 6;
    }
    *t += h;
  }
  if (steps >= MAX_STEPS)
    return "Solver has failed to finish in 1,000,000,000 steps";
  return 0;

#undef fn
}

static result_t set_data(solver_t *self, const ode_t *ode);
static result_t create(const argument_t *args);
static void destroy(solver_t *solver);

solver_output_t solver_output = {
    .name = "rk4",
    .args = (argument_t[]){{
                               .name = "h_max",
                               .type = REAL,
                               .r = 0.01,
                           },
                           {
                               .name = 0,
                               .type = 0,
                               .i = 0,
                           }},
    .malloc = malloc,
    .free = free,
    .create = create,
    .destroy = destroy,
};

static result_t set_data(solver_t *self, const ode_t *ode) {
  const I n = ode->x_size;
  const I size = (n * 5) * sizeof(R);
  if (n <= 0)
    return (result_t){.type = FAILURE,
                      .message = "ODE x_size must be positive"};
  if (self->n == n)
    return (result_t){.type = SUCCESS, .data = 0};
  if (self->data)
    solver_output.free(self->data);
  self->n = 0;
  self->data = 0;
  R *data = solver_output.malloc(size);
  if (!data)
    return (result_t){.type = FAILURE, .message = "Failed to allocate memory"};
  self->n = n;
  self->data = data;
  return (result_t){.type = SUCCESS, .data = 0};
}

static result_t create(const argument_t *args) {
  const R h_max = args[0].r;
  if (h_max <= 0 || h_max >= 0.5)
    return (result_t){.type = FAILURE,
                      .message = "h_max must satisfy: 0 < h_max < 0.5"};

  solver_t *solver = solver_output.malloc(sizeof(solver_t));
  argument_t *solver_args = solver_output.malloc(sizeof(argument_t) * 2);
  if (!solver || !solver_args) {
    if (solver)
      solver_output.free(solver);
    if (solver_args)
      solver_output.free(solver_args);
    return (result_t){.type = FAILURE, .message = "Failed to allocate memory"};
  }
  solver_t tmp = {
      .n = 0,
      .data = 0,
      .args = solver_args,
      .step = step,
      .set_data = set_data,
  };
  memcpy(solver, &tmp, sizeof(solver_t));
  memcpy(solver_args, args, sizeof(argument_t) * 2);
  return (result_t){.type = SUCCESS, .data = (void *)solver};
}

static void destroy(solver_t *solver) {
  solver_output.free((void *)solver->args);
  if (solver->data)
    solver_output.free(solver->data);
  solver_output.free((void *)solver);
}
