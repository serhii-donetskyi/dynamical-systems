#include "job/phase_portrait.h"
#include "ds.h"
#include <stdio.h>
#include <stdlib.h>

/**
 * @brief Writes an array of R type to a CSV file.
 * Each element of the array will be a value in a single row, separated by commas.
 * 
 * @param filename The name of the CSV file to write to.
 * @param solver The solver to use.
 * @return 0 on success, 1 on failure.
 */
N phase_portrait(const char *filename, solver_t *solver, R tend, N max_iters) {
    if (filename == NULL || solver == NULL) {
        fprintf(stderr, "Error: filename or data pointer is NULL.\n");
        return 1;
    }
    N iter = 0;
    const N n = solver->ode->n;
    const R *t = &solver->ode->t;
    const R *x = solver->ode->x;

    if (n == 0) {
        fprintf(stderr, "Error: n is 0.\n");
        return 1;
    }

    FILE *outfile = fopen(filename, "w");
    if (outfile == NULL) {
        perror("Error opening file for writing");
        return 1;
    }
    if (fprintf(outfile, "t") < 0) {
        perror("Error writing header to file");
        fclose(outfile);
        return 1;
    }
    for (N i = 0; i < n; ++i) {
        if (fprintf(outfile, ",x[%lu]", i) < 0) {
            perror("Error writing header to file");
            fclose(outfile);
            return 1;
        }
    }
    if (fprintf(outfile, "\n") < 0) {
        fprintf(stderr, "Error writing newline to file\n");
        fclose(outfile);
        return 1;
    }

    while (1){
        if (iter > max_iters) {
            fprintf(stderr, "Error: max_iters reached.\n");
            return 1;
        }
        if (*t >= tend) {
            break;
        }
        if (fprintf(outfile, "%g", *t) < 0) {
            perror("Error writing header to file");
            fclose(outfile);
            return 1;
        }
        for (N i = 0; i < n; ++i) {
            if (fprintf(outfile, ",%g", x[i]) < 0) { 
                fprintf(stderr, "Error writing data to file\n");
                fclose(outfile);
                return 1;
            }
        }
        if (fprintf(outfile, "\n") < 0) {
            fprintf(stderr, "Error writing newline to file\n");
            fclose(outfile);
            return 1;
        }
        solver->fn(solver);
        iter++;
    }

    if (fclose(outfile) == EOF) {
        perror("Error closing file");
        return 1;
    }

    return 0; // Success
}
