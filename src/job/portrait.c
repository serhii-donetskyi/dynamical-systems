#include "core.h"
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

const char* job(ode_t *restrict ode, solver_t *restrict solver, R *restrict data, const argument_t *restrict args) {
    char *error = 0;
    const I max_steps = 1000000000L;
    I steps = 0;

    R tstart = ode->t;
    I progress = 0;
    I progress_prev = 0;

    R tend = args[0].r;
    const char *file_path = args[1].s;

    if (tend < ode->t) {
        error = "t_end must be greater than ODE's t";
        return error;
    }

    fprintf(stderr, "DEBUG: File opened\n");
    FILE *file = fopen(file_path, "w");
    if (!file) error = strerror(errno);

    // printf("%ld\n", progress);

    for (; steps < max_steps; ++steps) {
        if (error) break;
        if (ode->t > tend) break;

        progress = (I)((ode->t - tstart) / (tend - tstart) * 100);
        if (progress > progress_prev) {
            // printf("%ld\n", progress);
            progress_prev = progress;
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
    if (progress < 100) {
        progress++;
        // printf("%ld\n", progress);
    }
    if (steps >= max_steps) error = "Job has failed to finish in 1,000,000,000 steps";
    fclose(file);
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
            .type = INTEGER,
            .i = 0,
        }
    },
};
