#include "core.h"
#include <stdlib.h>
#include <string.h>

static void fn(const ode_t *restrict self, R t, const R *restrict x,
               R *restrict dxdt) {
  (void)t;
  #define C (self->p[0])
  #define D (self->p[1])
  #define E (self->p[2])
  #define F (self->p[3])
  R tmp1 = (x[2] + (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]) / 8.0);
  R tmp2 = 0.75 * (x[0] * x[4] - x[1] * x[3]);
  dxdt[0] = C * x[0] - tmp1 * x[1] - tmp2 * x[3] + 2 * x[1];
  dxdt[1] = C * x[1] + tmp1 * x[0] - tmp2 * x[4] + 2 * x[0];
  dxdt[2] = D * (x[0] * x[1] + x[3] * x[4]) + E * x[2] + F;
  dxdt[3] = C * x[3] - tmp1 * x[4] + tmp2 * x[0] + 2 * x[4];
  dxdt[4] = C * x[4] + tmp1 * x[3] + tmp2 * x[1] + 2 * x[3];
  #undef C
  #undef D
  #undef E
  #undef F
}

static result_t create(const argument_t *args);
static void destroy(ode_t *ode);

DS_EXPORT
ode_output_t ode_output = {
    .name = "spherical_pendulum",
    .args = (argument_t[]){
                           {
                               .name = 0,
                               .type = 0,
                               .r = 0,
                           }},
    .malloc = malloc,
    .free = free,
    .create = create,
    .destroy = destroy,
};

static result_t create(const argument_t *args) {
  const I x_size = 5;
  const I p_size = 4;
  const I arg_size = 1;

  ode_t *ode = ode_output.malloc(sizeof(ode_t));
  argument_t *ode_args = ode_output.malloc(sizeof(argument_t) * arg_size);
  R *x = ode_output.malloc(x_size * sizeof(R));
  R *p = ode_output.malloc(p_size * sizeof(R));
  if (!ode || !ode_args || !x || !p) {
    if (ode)
      ode_output.free(ode);
    if (ode_args)
      ode_output.free(ode_args);
    if (x)
      ode_output.free(x);
    if (p)
      ode_output.free(p);
    return (result_t){.type = FAILURE, .message = "Failed to allocate memory"};
  }
  ode_t tmp = {
      .args = ode_args,
      .fn = fn,
      .x_size = x_size,
      .p_size = p_size,
      .x = x,
      .p = p,
  };
  memcpy(ode, &tmp, sizeof(ode_t));
  memcpy(ode_args, args, sizeof(argument_t) * arg_size);

  return (result_t){.type = SUCCESS, .data = (void *)ode};
}

static void destroy(ode_t *ode) {
  ode_output.free((void *)ode->args);
  ode_output.free((void *)ode->x);
  ode_output.free((void *)ode->p);
  ode_output.free((void *)ode);
}
