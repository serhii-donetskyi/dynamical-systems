#include "core.h"
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#define MAX_STEPS 1000000000L

const char* job(ode_t *restrict ode, solver_t *restrict solver, R *restrict data, const argument_t *restrict args) {
    char *error = 0;
    I steps = 0;

    const R t_start = ode->t;
    I progress = 0;
    I progress_next = 0;

    const R t_end = args[0].r;
    const char *file_path = args[1].s;

    if (t_end < ode->t) {
        error = "t_end must be greater than ODE's t";
        return error;
    }

    FILE *file = fopen(file_path, "w");
    if (!file) error = strerror(errno);

    printf("%ld\n", progress);
    fflush(stdout);

    for (; steps < MAX_STEPS; ++steps) {
        if (error) break;
        if (ode->t > t_end) break;

        progress_next = (I)((ode->t - t_start) / (t_end - t_start) * 100);
        while (progress < progress_next){
            progress++;
            printf("%ld\n", progress);
            fflush(stdout);
        }
        
        // Write current state to file
        if (fprintf(file, "%.6f", ode->t) < 0) {
            error = "Failed to write to file";
        } else{
            for (I i = 0; i < ode->x_size; i++) {
                if (fprintf(file, " %.6f", ode->x[i]) < 0){
                    error = "Failed to write to file";
                    break;
                }
            }
            if (fprintf(file, "\n") < 0) error = "Failed to write to file";
        }
        solver->step(ode, solver, data);
    }
    if (steps >= MAX_STEPS) error = "Job has failed to finish in 1,000,000,000 steps";
    fclose(file);
    if (!error){
        while (progress < 100){
            progress++;
            printf("%ld\n", progress);
            fflush(stdout);
        }
    }
    return error;
}

job_output_t job_output = {
    .name = "portrait",
    .fn = job,
    .args = (argument_t[]){
        {
            .name = "t_end",
            .type = REAL,
            .r = 1.0,
        },
        {
            .name = "file_path",
            .type = STRING,
            .s = "portrait.dat",
        },
        {
            .name = 0,
            .type = 0,
            .i = 0,
        }
    },
};

#undef MAX_STEPS
