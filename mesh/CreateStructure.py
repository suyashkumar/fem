"""
CreateStructure.py

Create "simple" structures in the FE meshes (e.g., spheres, layers).

Copyright 2014 Mark L. Palmeri (mlp6@duke.edu)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
===============================================================================
"""

__author__ = "Mark Palmeri"
__email__ = "mlp6@duke.edu"
__license__ = "Apache v2.0"


def main():
    import sys
    import fem_mesh

    fem_mesh.check_version()

    # lets read in some CLI arguments
    args = parse_cli()

    # find nodes in the structure and assign them to a dictionary
    structNodeIDs = findStructNodeIDs(args)

    # find elements that contain the structure nodes
    (elems, structElemIDs) = findStructElemIDs(args.elefile, structNodeIDs)

    # generate the new element file with the structure elements assigned the
    # new part ID
    NEFILE = open(args.nefile, 'w')
    NEFILE.write("$ Generated using %s with the following "
                 "options:\n" % (sys.argv[0]))
    NEFILE.write("$ %s\n" % args)
    NEFILE.write('$ # Structure Nodes = %i\n' % structNodeIDs.__len__())
    NEFILE.write('$ # Structure Elements = %i\n' % structElemIDs.__len__())
    NEFILE.write('*ELEMENT_SOLID\n')
    for i in elems:
        if i[0] in structElemIDs:
            i[1] = args.partid
        j = i.tolist()
        NEFILE.write('%s\n' % ','.join('%i' % val for val in j[0:10]))
    NEFILE.write('*END')
    NEFILE.close()


def parse_cli():
    import argparse

    par = argparse.ArgumentParser(
        description="Generate new element structure file as specified on the"
        "command line.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    par.add_argument("--nefile", dest="nefile", help="new element definition"
                     "output file", default="struct.dyn")
    par.add_argument("--nodefile",
                     dest="nodefile",
                     help="node definition input file",
                     default="nodes.dyn")
    par.add_argument("--elefile",
                     dest="elefile",
                     help="element definition input file",
                     default="elems.dyn")
    par.add_argument("--partid",
                     dest="partid",
                     help="part ID to assign to the new structure",
                     default=2)
    s = par.add_mutually_exclusive_group(required=True)

    s.add_argument("--sphere",
                   help="center x, y, z, radius",
                   action="store_true")
    s.add_argument("--layer",
                   help="normal dir, min max",
                   action="store_true")
    s.add_argument("--ellipsoid",
                   help="center x, y, z, axis 1/2 length a, b, c, "
                        "Euler angle phi, theta, psi (deg)",
                   action="store_true")
    s.add_argument("--cube",
                   help="corner x, y, z, length x, y, z",
                   action="store_true")

    par.add_argument("--sopts",
                     dest="sopts",
                     help="struct options (see help for each struct type)",
                     nargs='+',
                     type=float,
                     required=True)

    args = par.parse_args()

    return args


def findStructNodeIDs(args):
    import sys
    import numpy as n
    import math as m
    import fem_mesh

    header_comment_skips = fem_mesh.count_header_comment_skips(args.nodefile)
    nodeIDcoords = n.loadtxt(args.nodefile,
                             delimiter=',',
                             skiprows=header_comment_skips,
                             comments='*',
                             dtype=[('id', 'i4'), ('x', 'f4'),
                                    ('y', 'f4'), ('z', 'f4')])

    structNodeIDs = {}

    sopts = args.sopts

    if args.sphere:
        '''
        sopts is assumed to be a 4 element tuple with the following items:
        sphere center coordinates (x,y,z)
        sphere radius
        '''
        for i in nodeIDcoords:
            nodeRad = n.sqrt(n.power((i[1] - sopts[0]), 2) +
                             n.power((i[2] - sopts[1]), 2) +
                             n.power((i[3] - sopts[2]), 2))
            if nodeRad < sopts[3]:
                structNodeIDs[i[0]] = True

    elif args.layer:
        '''
        sopts is assumed to be a 3 element tuple with the following items:
        dimension for normal to layer (x = 1, y = 2, z = 3)
        layer bounds (min,max)
        '''
        for i in nodeIDcoords:
            if i[sopts[0]] > sopts[1] and i[sopts[0]] < sopts[2]:
                structNodeIDs[i[0]] = True

    elif args.ellipsoid:
        '''
        sopts is assumed to be a 9 element tuple with the following items:
        ellipsoid center coordinates (x,y,z)
        ellipsoid half-axis lengths (a,b,c)
        ellipsoid euler angles (phi,theta,psi) in DEGREES
        '''
        cph = m.cos(m.radians(sopts[6]))    # cos(phi)
        sph = m.sin(m.radians(sopts[6]))    # sin(phi)
        cth = m.cos(m.radians(sopts[7]))    # cos(theta)
        sth = m.sin(m.radians(sopts[7]))    # sin(theta)
        cps = m.cos(m.radians(sopts[8]))    # cos(psi)
        sps = m.sin(m.radians(sopts[8]))    # sin(psi)

        # rotation matrix
        R = n.matrix([[cth * cps, -cph * sps + sph * sth * cps, sph * sps +
                       cph * sth * cps],
                      [cth * sps, cph * cps + sph * sth * sps,
                       -sph * cps + cph * sth * sps],
                      [-sth, sph * cth, cph * cth]])
        # diagonal maxtrix of squared ellipsoid half-axis lengths
        A = n.matrix([[n.power(sopts[3], 2), 0, 0],
                      [0, n.power(sopts[4], 2), 0],
                      [0, 0, n.power(sopts[5], 2)]])
        # A matrix - eigenvalues are a^2,b^2,c^2 (square of half-axis lengths),
        # eigenvectors are directions of the orthogonal principal axes
        A = R.transpose().dot(A).dot(R)

        # locate nodes within ellipsoid
        for i in nodeIDcoords:
            radVec = n.matrix([[i[1] - sopts[0]],
                               [i[2] - sopts[1]],
                               [i[3] - sopts[2]]])
            if radVec.transpose().dot(A.I).dot(radVec) <= 1:
                structNodeIDs[i[0]] = True

    elif args.cube:
        '''
        sopts is assumed to be a 6 element tuple with the following items:
        Location of most-negative corner (x,y,z) Respective cube dimensions
        (x,y,z)
        '''
        for i in nodeIDcoords:
            if i[1] >= sopts[0] and \
                i[1] <= (sopts[0] + sopts[3]) and \
                i[2] >= sopts[1] and \
                i[2] <= (sopts[1] + sopts[4]) and \
                i[3] >= sopts[2] and \
                    i[3] <= (sopts[2] + sopts[5]):
                        structNodeIDs[i[0]] = True

    else:
        sys.exit('ERROR: The specified structure is not defined')

    if len(structNodeIDs) == 0:
        sys.exit('ERROR: no structure nodes were found')

    return structNodeIDs


def findStructElemIDs(elefile, structNodeIDs):
    import sys
    import numpy as n
    import fem_mesh

    header_comment_skips = fem_mesh.count_header_comment_skips(elefile)
    elems = n.loadtxt(elefile,
                      delimiter=',',
                      comments='*',
                      skiprows=header_comment_skips,
                      dtype=[('id', 'i4'), ('pid', 'i4'), ('n1', 'i4'),
                             ('n2', 'i4'), ('n3', 'i4'), ('n4', 'i4'),
                             ('n5', 'i4'), ('n6', 'i4'), ('n7', 'i4'),
                             ('n8', 'i4')])

    structElemIDs = {}

    for i in elems:
        # I hate this hard-coded syntax, but this works (for now)
        j = i.tolist()
        insideStruct = any(x in structNodeIDs for x in j[2:10])
        if insideStruct:
            structElemIDs[i[0]] = True

    if structElemIDs.__len__ == 0:
        sys.exit('ERROR: no structure elements were found')

    return (elems, structElemIDs)


if __name__ == "__main__":
    main()
