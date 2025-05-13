#ifndef PHASE_PORTRAIT_H
#define PHASE_PORTRAIT_H

#include <stdio.h> // For size_t
#include "ds.h"     // For R type

// Function declaration
/**
 * @brief Writes an array of R type to a CSV file.
 * Each element of the array will be a value in a single row, separated by commas.
 * 
 * @param filename The name of the CSV file to write to.
 * @param solver The solver to use.
 * @return 0 on success, -1 on failure.
 */
N phase_portrait(const char *filename, solver_t *solver, R tend, N max_iters);

#endif // PHASE_PORTRAIT_H 
