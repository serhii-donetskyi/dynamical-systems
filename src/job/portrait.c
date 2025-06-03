#include "core.h"
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

const char* job(ode_t *restrict ode, solver_t *restrict solver, R *restrict data, const argument_t *restrict args) {
    char *error = 0;
    I steps = 0;

    R tend = args[0].r;
    I max_steps = args[1].i;
    const char *file_path = args[2].s;
    FILE *file = fopen(file_path, "w");
    if (!file) error = strerror(errno);

    for (; steps < max_steps; ++steps) {
        if (error) break;
        if (ode->t > tend) break;
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
    if (steps >= max_steps) error = "Max steps reached";
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
            .name = "max_steps",
            .type = INTEGER,
            .i = 1000000,
        },
        {
            .name = "file_path",
            .type = STRING,
            .s = "portrait.dat",
        },
        {
            .name = 0,
            .type = REAL,
            .r = 0.0,
        }
    },
};
