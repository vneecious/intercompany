*"* use this source file for any type of declarations (class
*"* definitions, interfaces or type declarations) you need for
*"* components in the private section

CLASS ltcl_pipeline DEFINITION DEFERRED.
CLASS ltcl_an2_exact DEFINITION DEFERRED.
CLASS ltcl_fx_v2 DEFINITION DEFERRED.
CLASS zcl_reing_ca_pipeline DEFINITION LOCAL FRIENDS ltcl_pipeline ltcl_an2_exact ltcl_fx_v2.
