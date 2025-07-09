#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "core.h"

#define MAX_STEPS 1000000000L

// Cross-platform safe error string function
static const char *safe_strerror(int errnum) {
#ifdef _MSC_VER
  static char buffer[256];
  if (strerror_s(buffer, sizeof(buffer), errnum) == 0) {
    return buffer;
  }
  return "Unknown error";
#else
  return strerror(errnum);
#endif
}

static const char *solout(FILE *file, const ode_t *ode) {
  const char *error = "Failed to write to file";
  if (fprintf(file, "%.6f", ode->t) < 0)
    return error;
  for (I i = 0; i < ode->x_size; i++)
    if (fprintf(file, " %.6f", ode->x[i]) < 0)
      return error;
  if (fprintf(file, "\n") < 0)
    return error;
  return 0;
}

static result_t job(ode_t *restrict ode, solver_t *restrict solver,
                    const argument_t *restrict args) {
  result_t result = {.type = SUCCESS, .data = 0};
  I steps = 0;

  const R t_start = ode->t;
  I progress = 0;
  I progress_next = 0;

  const R t_step = args[0].r;
  const R t_end = args[1].r;
  const char *file_path = args[2].s;

  if (t_step <= 0) {
    result.type = FAILURE;
    result.message = "t_step must be positive";
    return result;
  }
  if (t_end <= ode->t) {
    result.type = FAILURE;
    result.message = "t_end must be greater than ODE.t";
    return result;
  }
  if (t_step > (t_end - ode->t)) {
    result.type = FAILURE;
    result.message = "t_step cannot be greater than (t_end - ODE.t)";
    return result;
  }

  FILE *file = fopen(file_path, "w");
  if (!file) {
    result.type = FAILURE;
    result.message = safe_strerror(errno);
    return result;
  }

  if (fprintf(file, "t") < 0) {
    result.type = FAILURE;
    result.message = "Failed to write to file";
  }
  for (I i = 0; i < ode->x_size; i++)
    if (fprintf(file, " x[%" PRI_I "]", i) < 0) {
      result.type = FAILURE;
      result.message = "Failed to write to file";
      break;
    }
  if (fprintf(file, "\n") < 0) {
    result.type = FAILURE;
    result.message = "Failed to write to file";
  }
  result.message = solout(file, ode);
  if (result.message)
    result.type = FAILURE;

  printf("%" PRI_I "\n", progress);
  fflush(stdout);

  for (; steps < MAX_STEPS; ++steps) {
    if (result.type == FAILURE)
      break;
    if (ode->t >= t_end)
      break;

    progress_next = (I)((ode->t - t_start) / (t_end - t_start) * 100);
    while (progress < progress_next) {
      progress++;
      printf("%" PRI_I "\n", progress);
      fflush(stdout);
    }
    result.message =
        solver->step(solver, ode, &ode->t, ode->x, ode->t + t_step);
    if (result.message) {
      result.type = FAILURE;
      break;
    }

    result.message = solout(file, ode);
    if (result.message) {
      result.type = FAILURE;
      break;
    }
  }
  fclose(file);
  if (steps >= MAX_STEPS) {
    result.type = FAILURE;
    result.message = "Job has failed to finish in 1,000,000,000 steps";
  }
  if (result.type == SUCCESS) {
    while (progress < 100) {
      progress++;
      printf("%" PRI_I "\n", progress);
      fflush(stdout);
    }
  }
  return result;
}

DS_EXPORT
job_output_t job_output = {
    .name = "portrait",
    .args = (argument_t[]){{
                               .name = "t_step",
                               .type = REAL,
                               .r = 0.01,
                           },
                           {
                               .name = "t_end",
                               .type = REAL,
                               .r = 1.0,
                           },
                           {
                               .name = "file",
                               .type = STRING,
                               .s = "portrait.dat",
                           },
                           {
                               .name = 0,
                               .type = 0,
                               .i = 0,
                           }},
    .fn = job,
};

#undef MAX_STEPS
