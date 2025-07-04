#include "core.h"
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#define MAX_STEPS 1000000000L

static const char *solout(FILE *file, const ode_t *ode) {
    const char *error = "Failed to write to file";
    if (fprintf(file, "%.6f", ode->t) < 0) return error;
    for (I i = 0; i < ode->x_size; i++)
        if (fprintf(file, " %.6f", ode->x[i]) < 0) return error;
    if (fprintf(file, "\n") < 0) return error;
    return 0;
}

static result_t job(ode_t *restrict ode, solver_t *restrict solver, const argument_t *restrict args) {
    result_t result = {.type = SUCCESS, .data = 0};
    I steps = 0;

    const R t_start = ode->t;
    I progress = 0;
    I progress_next = 0;

    const R h = args[0].r;
    const R t_end = args[1].r;
    const char *file_path = args[2].s;

    if (h <= 0) {
        result.type = FAILURE;
        result.message = "h must be positive";
        return result;
    }

    if (t_end < ode->t) {
        result.type = FAILURE;
        result.message = "t_end must be greater than ODE's t";
        return result;
    }

    FILE *file = fopen(file_path, "w");
    if (!file) {
        result.type = FAILURE;
        result.message = strerror(errno);
        return result;
    }

    if (fprintf(file, "t") < 0) {
        result.type = FAILURE;
        result.message = "Failed to write to file";
    }
    for (I i = 0; i < ode->x_size; i++) 
        if (fprintf(file, " x[%ld]", i) < 0) {
            result.type = FAILURE;
            result.message = "Failed to write to file";
            break;
        }
    if (fprintf(file, "\n") < 0) {
        result.type = FAILURE;
        result.message = "Failed to write to file";
    }
    result.message = solout(file, ode);
    if (result.message) result.type = FAILURE;

    printf("%ld\n", progress);
    fflush(stdout);

    for (; steps < MAX_STEPS; ++steps) {
        if (result.type == FAILURE) break;
        if (ode->t > t_end) break;

        progress_next = (I)((ode->t - t_start) / (t_end - t_start) * 100);
        while (progress < progress_next){
            progress++;
            printf("%ld\n", progress);
            fflush(stdout);
        }
        result.message = solver->step(solver, ode, &ode->t, ode->x, ode->t + h);
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
    if (result.type == SUCCESS){
        while (progress < 100){
            progress++;
            printf("%ld\n", progress);
            fflush(stdout);
        }
    }
    return result;
}

job_output_t job_output = {
    .name = "portrait",
    .args = (argument_t[]){
        {
            .name = "h",
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
        }
    },
    .fn = job,
};

#undef MAX_STEPS
