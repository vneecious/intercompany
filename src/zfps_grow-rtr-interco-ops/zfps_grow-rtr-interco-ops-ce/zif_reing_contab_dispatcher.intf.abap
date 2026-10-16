*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Change ID      : V001                                                *
* Date           : 02.07.2026                                          *
* Description    : Reintegro Gastos - Motor de Calculo IC - F0 Fundaciones y DDIC *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* CONTAB contract (skeleton). CA owns the contract because ET-REING-CONTAB-001
* is not released (T-04). The mock ZCL_REING_CA_CONTAB_STUB is scope of F4.
*----------------------------------------------------------------------*
"Begin Insert V001 (CC)
INTERFACE zif_reing_contab_dispatcher PUBLIC.

  METHODS process_line
    IMPORTING
      is_line_a        TYPE zreing_ca_line_a
      it_line_pc       TYPE zif_reing_ca_types=>ty_line_pc_t
      it_step_a        TYPE zif_reing_ca_types=>ty_step_t
      iv_mode          TYPE zreing_ca_contab_mode
    RETURNING
      VALUE(rs_result) TYPE zif_reing_ca_types=>ty_contab_result.

ENDINTERFACE.
"End Insert V001 (CC)
