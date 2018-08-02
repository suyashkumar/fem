/*
 * This example shows how to create a compound data type with an array member,
 * and write an array which has the compound data type to the file.
 *
 * works for simple array in FieldParams struct.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <hdf5.h>
/* #include "field.h" */

#define FILE          "dyna.mat"
#define DATASETNAME   "FIELD_PARAMS"
#define LENGTH        10
#define RANK          1
#define ARRAY_RANK    1
#define ARRAY_DIM     3 

struct nodeEntry {
	int nodeID;
	double x, y, z;
	};

struct FieldParams {
	double alpha;
	double b[10];
	double c[10];
	double d[10];
	};

int
main(void)
{
int i, numNodes;
char *nodeName;
char *elemName;
int lowNslow;
int forceNonLinear;
hsize_t dim = 1;

struct nodeEntry *pointsAndNodes, *readMpn(), *temp;
struct FieldParams fieldParams;

hid_t      file, dataset, space; /* Handles */
hid_t      array_tid_b, array_tid_c, array_tid_d; /* Array datatype handle */
hid_t      s1_tid;     /* File datatype identifier */
herr_t     status;

#if 0
    /* First structure  and dataset*/
    typedef struct s1_t {
	int    a;
	float  b[ARRAY_DIM];
    } s1_t;
    s1_t       s1[LENGTH];

    hsize_t    dim[] = {LENGTH};   /* Dataspace dimensions */
    hsize_t    array_dim[] = {ARRAY_DIM};   /* Array dimensions */

    int        i, j;

    /*
     * Initialize the data
     */
    for (i = 0; i< LENGTH; i++) {
        s1[i].a = i;
        for (j = 0; j < ARRAY_DIM; j++) {
             s1[i].b[j] = i+j;
        }
    }
#endif

	nodeName = "./myNodesShort.dyn";
	fieldParams.alpha = 0.6;

	temp = readMpn(nodeName, &numNodes);
    for (i = 0; i < numNodes; i++) {
		fieldParams.b[i] = temp[i].x;
		fieldParams.c[i] = temp[i].y;
		fieldParams.d[i] = temp[i].z;
		}


	fprintf(stderr, "after readMpn; numNodes %d\n", numNodes);


    /*
     * Create the data space.
     */
    space = H5Screate_simple(RANK, &dim, NULL);

    /*
     * Create the file.
     */
    file = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);

    /*
     * Create the array data type. 
     */
hsize_t nodes[] = {numNodes};

fprintf(stderr, "nodes[0] is %d\n", nodes[0]);

     array_tid_b = H5Tarray_create(H5T_NATIVE_DOUBLE, ARRAY_RANK, nodes);
/*
     array_tid_c = H5Tarray_create(H5T_NATIVE_DOUBLE, ARRAY_RANK, nodes);
     array_tid_d = H5Tarray_create(H5T_NATIVE_DOUBLE, ARRAY_RANK, nodes);
*/

    /*
     * Create the memory data type. 
     */
	i = sizeof(double) + numNodes * 3 * 10 * sizeof(double);

	fprintf(stderr, "i is %d\n", i);

    s1_tid = H5Tcreate (H5T_COMPOUND, i);
    H5Tinsert(s1_tid, "a_name", HOFFSET(struct FieldParams, alpha), H5T_NATIVE_DOUBLE);
    H5Tinsert(s1_tid, "b_name", HOFFSET(struct FieldParams, b), array_tid_b);
    H5Tinsert(s1_tid, "c_name", HOFFSET(struct FieldParams, c), array_tid_b);
    H5Tinsert(s1_tid, "d_name", HOFFSET(struct FieldParams, d), array_tid_b);

    /* 
     * Create the dataset.
     */
    dataset = H5Dcreate(file, DATASETNAME, s1_tid, space, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);

    /*
     * Wtite data to the dataset; 
     */
    status = H5Dwrite(dataset, s1_tid, H5S_ALL, H5S_ALL, H5P_DEFAULT, &fieldParams);

    /*
     * Release resources
     */
    H5Tclose(s1_tid);
    H5Tclose(array_tid_b);
    H5Sclose(space);
    H5Dclose(dataset);
    H5Fclose(file);
 
#if 0
#endif

    return 0;
}
