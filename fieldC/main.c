/* test routine */

#include <stdio.h>
#include "field.h"

sys_con_type   *sys_con;

main()
{
int i;
char *field2dyna();
point_type focus;

	focus.x = 0;
	focus.y = 0;
	focus.z = 0.02;

/*
field2dyna(char *nodeName, double alpha, double fnum, struct Focus focus,
    double freq, char *transducer, char *impulse, int threads, int lowNslow,
	    char *elemName, int forceNonlinear)
*/

field2dyna("./myNodes.dyn", .5, 1.3, focus, 7.2, "vf105", "gaussian", 1, 0,
	"../tests/elems.dyn", 0);

}
