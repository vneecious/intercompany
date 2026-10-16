*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : Orphan Recovery (F5) - Motor de Calculo CA          *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Conservative stub of ZIF_REING_CA_ORPHAN_VERIFY (F5-DD-3): always
* answers "document does not exist" until F5-03 (dependent on the
* CONTAB team's engine) ships the real verification. This is
* deliberately safe -- see ZCL_REING_CA_ORPHAN_REC~recover_line, which
* logs explicitly that the POST_PROC/ANUL_PROC result came from the
* stub, not from a real FI check.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_orphan_stub DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_orphan_verify.

  PRIVATE SECTION.
    " Call counter -- useful for unit test assertions (F5-04).
    DATA mv_call_count TYPE i.

ENDCLASS.


CLASS zcl_reing_ca_orphan_stub IMPLEMENTATION.

  METHOD zif_reing_ca_orphan_verify~exists_bkpf_for_line.
    " F5-DD-3: conservative branch -- always "document does not exist"
    " until F5-03 implements the real BKPF lookup.
    mv_call_count = mv_call_count + 1.
    rv_exists = abap_false.
  ENDMETHOD.

  METHOD zif_reing_ca_orphan_verify~exists_storno_for_line.
    " F5-DD-3: conservative branch -- always "document does not exist"
    " until F5-03 implements the real reversal lookup.
    mv_call_count = mv_call_count + 1.
    rv_exists = abap_false.
  ENDMETHOD.

ENDCLASS.

