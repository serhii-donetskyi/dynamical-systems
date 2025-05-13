#include "ds.h"
#include "solver/rk4.h"
#include "ode/linear.h"
#include "job/phase_portrait.h"
#include <stdio.h>

int main(void) {

    ode_t ode = ode_linear_create(2, 0, (R[]){0, 1}, (R[]){0, 1, -1, 0});
    solver_t solver = solver_rk4_create(&ode, 0.01);

    int status = phase_portrait("phase_portrait.csv", &solver, 10, 100000000);
    if (status != 0) {
        fprintf(stderr, "Error: phase_portrait returned %d\n", status);
        return 1;
    }

    solver_free(&solver);
    ode_free(&ode);
    return 0;
}
