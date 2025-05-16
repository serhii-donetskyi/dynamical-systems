#ifndef COMMON_H
#define COMMON_H

typedef unsigned long N;
typedef double R;

_Static_assert(sizeof(R) == sizeof(N), "R and N must have the same size");

#endif // COMMON_H 
