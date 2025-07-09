#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core.h"

#define MAX_STEPS 1000000000

// DOPRI5 Butcher tableau constants
#define C2 (2.0 / 10.0)
#define C3 (3.0 / 10.0)
#define C4 (8.0 / 10.0)
#define C5 (8.0 / 9.0)

#define A21 (2.0 / 10.0)

#define A31 (3.0 / 40.0)
#define A32 (9.0 / 40.0)

#define A41 (44.0 / 45.0)
#define A42 (-56.0 / 15.0)
#define A43 (32.0 / 9.0)

#define A51 (19372.0 / 6561.0)
#define A52 (-25360.0 / 2187.0)
#define A53 (64448.0 / 6561.0)
#define A54 (-212.0 / 729.0)

#define A61 (9017.0 / 3168.0)
#define A62 (-355.0 / 33.0)
#define A63 (46732.0 / 5247.0)
#define A64 (49.0 / 176.0)
#define A65 (-5103.0 / 18656.0)

#define A71 (35.0 / 384.0)
#define A73 (500.0 / 1113.0)
#define A74 (125.0 / 192.0)
#define A75 (-2187.0 / 6784.0)
#define A76 (11.0 / 84.0)

#define E1 (71.0 / 57600.0)
#define E3 (-71.0 / 16695.0)
#define E4 (71.0 / 1920.0)
#define E5 (-17253.0 / 339200.0)
#define E6 (22.0 / 525.0)
#define E7 (-1.0 / 40.0)

static result_t set_data(solver_t *self, const ode_t *ode);
static result_t create(const argument_t *args);
static void destroy(solver_t *solver);

DS_EXPORT
solver_output_t solver_output = {
    .name = "dopri5",
    .args = (argument_t[]){{
                               .name = "h_max",
                               .type = REAL,
                               .r = 0.1,
                           },
                           {
                               .name = "eps",
                               .type = REAL,
                               .r = 1e-3,
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

static R max_of_three(R v1, R v2, R v3) { return fmax(fmax(v1, v2), v3); }

static const char *step(solver_t *restrict self, const ode_t *restrict ode,
                        R *restrict t, R *restrict x, R t_end) {
#define fn(t, x, dxdt) (ode->fn(ode, t, x, dxdt))

  const I n = self->n;
  const R h_max = self->args[0].r;
  const R eps = self->args[1].r;

  I *reject_ptr = (I *)(self->data);
  R *h_ptr = (R *)(self->data) + 1;
  R *y = h_ptr + 1;
  R *k1 = y + n;
  R *k2 = k1 + n;
  R *k3 = k2 + n;
  R *k4 = k3 + n;
  R *k5 = k4 + n;
  R *k6 = k5 + n;

  const I sign = t_end > *t ? 1 : -1;
  R h = *h_ptr;
  I reject = (I)(*reject_ptr);
  if (h * sign <= 0 || h * sign >= h_max)
    h = sign * h_max;

  I steps = 0;
  for (; steps < MAX_STEPS; steps++) {
    if (sign * (*t - t_end) >= 0)
      break;
    if (sign * (*t + h - t_end) >= 0)
      h = t_end - *t + sign * 1e-10;

    // Stage 1
    fn(*t, x, k1);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * A21 * k1[i];
    }

    // Stage 2
    fn(*t + h * C2, y, k2);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * (A31 * k1[i] + A32 * k2[i]);
    }

    // Stage 3
    fn(*t + h * C3, y, k3);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * (A41 * k1[i] + A42 * k2[i] + A43 * k3[i]);
    }

    // Stage 4
    fn(*t + h * C4, y, k4);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * (A51 * k1[i] + A52 * k2[i] + A53 * k3[i] + A54 * k4[i]);
    }

    // Stage 5
    fn(*t + h * C5, y, k5);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * (A61 * k1[i] + A62 * k2[i] + A63 * k3[i] + A64 * k4[i] +
                         A65 * k5[i]);
    }

    // Stage 6
    R tph = *t + h;
    fn(tph, y, k6);
    for (I i = 0; i < n; i++) {
      y[i] = x[i] + h * (A71 * k1[i] + A73 * k3[i] + A74 * k4[i] + A75 * k5[i] +
                         A76 * k6[i]);
    }

    // Stage 7 (for error estimation)
    fn(tph, y, k2);

    // Error estimation
    for (I i = 0; i < n; i++) {
      k4[i] = h * (E1 * k1[i] + E3 * k3[i] + E4 * k4[i] + E5 * k5[i] +
                   E6 * k6[i] + E7 * k2[i]);
    }

    R err = 0;
    for (I i = 0; i < n; i++) {
      R rerr = k4[i] / max_of_three(1e-5, fabs(x[i]), fabs(y[i]));
      err += rerr * rerr;
    }
    err = sqrt(err / n);
    R fac = fmax(fmin(pow(eps / err, 0.2), 5.0), 0.2);
    R h_new = h * fac;

    if (err < eps) {
      // Step accepted
      *t = tph;
      for (I i = 0; i < n; i++) {
        x[i] = y[i];
      }
      if (fabs(h_new) > h_max)
        h_new = sign * h_max;
      if (reject)
        h_new = fmin(fabs(h_new), h_max) * sign;
      reject = 0;
    } else {
      // Step rejected
      if (fabs(h_new) > fabs(h))
        h_new = h;
      if (h_new != h_new)
        h_new = 0.6 * h; // h_new is NaN
      if (reject)
        h_new *= 0.9;
      reject = 1;
    }
    h = h_new;
  }

  // Store state for next call
  *h_ptr = h;
  *reject_ptr = reject;

  if (steps >= MAX_STEPS)
    return "Solver has failed to finish in 1,000,000,000 steps";
  return 0;

#undef fn
}

static result_t set_data(solver_t *self, const ode_t *ode) {
  const I n = ode->x_size;
  const I size = (2 + n * 7) * sizeof(R); // reject flag + h + 7 work arrays
  if (n <= 0)
    return (result_t){.type = FAILURE,
                      .message = "ODE x_size must be positive"};
  if (self->n == n)
    return (result_t){.type = SUCCESS, .data = 0};
  if (self->data)
    solver_output.free(self->data);
  self->n = 0;
  self->data = 0;
  R *data = (R *)solver_output.malloc(size);
  if (!data)
    return (result_t){.type = FAILURE, .message = "Failed to allocate memory"};

  // Initialize step size and reject flag
  data[0] = 0;   // reject flag
  data[1] = 0.0; // h = h_max

  self->n = n;
  self->data = data;
  return (result_t){.type = SUCCESS, .data = 0};
}

static result_t create(const argument_t *args) {
  const R h_max = args[0].r;
  const R eps = args[1].r;
  if (h_max <= 0 || h_max >= 1)
    return (result_t){.type = FAILURE,
                      .message = "h_max must satisfy: 0 < h_max < 1"};
  if (eps <= 0 || eps >= 1)
    return (result_t){.type = FAILURE,
                      .message = "eps must satisfy: 0 < eps < 1"};

  solver_t *solver = solver_output.malloc(sizeof(solver_t));
  argument_t *solver_args = solver_output.malloc(sizeof(argument_t) * 3);
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
  memcpy(solver_args, args, sizeof(argument_t) * 3);
  return (result_t){.type = SUCCESS, .data = (void *)solver};
}

static void destroy(solver_t *solver) {
  solver_output.free((void *)solver->args);
  if (solver->data)
    solver_output.free(solver->data);
  solver_output.free((void *)solver);
}
