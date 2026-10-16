*"* use this source file for any type of declarations (class
*"* definitions, interfaces or type declarations) you need for
*"* components in the private section

CLASS ltcl_an2_calc DEFINITION DEFERRED.
CLASS zcl_reing_ca_calc_job DEFINITION LOCAL FRIENDS ltcl_an2_calc.
