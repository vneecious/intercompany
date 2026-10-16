*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : Orphan Recovery (F5) - Motor de Calculo CA          *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Isolated extension point for the real FI document verification that
* F5-03 (dependent on the CONTAB team's ZCL_REING_CONTAB_ENGINE, still
* not released) will implement. F5 ships only a conservative stub
* (ZCL_REING_CA_ORPHAN_STUB) against this interface -- same decoupling
* pattern already used in the project for CONTAB (F4:
* ZIF_REING_CONTAB_DISPATCHER / ZCL_REING_CA_CONTAB_STUB).
*----------------------------------------------------------------------*
INTERFACE zif_reing_ca_orphan_verify
  PUBLIC.

  "! Checks whether a real posted FI document (BKPF) exists for the line.
  "! Real implementation pending F5-03 -- this phase only ships a stub.
  METHODS exists_bkpf_for_line
    IMPORTING
      is_line          TYPE zreing_ca_line_a
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

  "! Checks whether a real reversal (storno) document exists for the line.
  "! Real implementation pending F5-03 -- this phase only ships a stub.
  METHODS exists_storno_for_line
    IMPORTING
      is_line          TYPE zreing_ca_line_a
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

ENDINTERFACE.
