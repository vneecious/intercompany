class ZCL_INTERCO_CPH_DATA_LOAD_WT definition
  public
  final
  create public .

public section.

  types:
    ty_cph  TYPE STANDARD TABLE OF zfi_a_intrc_cph .

  class-methods DELETE_RELATEDPROPOSAL
    importing
      !I_UUID type UUID .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCO_CPH_DATA_LOAD_WT IMPLEMENTATION.


  METHOD delete_relatedproposal.

    IF i_uuid IS INITIAL.
      RETURN.
    ENDIF.

*    DELETE FROM zfi_a_intrc_cpdf WHERE id EQ @i_UUID.
    DELETE FROM zfi_a_intrc_cpid WHERE id EQ @i_uuid.
    DELETE FROM zfi_a_intrc_cpic WHERE id EQ @i_uuid.
    DELETE FROM zfi_a_intrc_cpib WHERE id EQ @i_uuid.
    DELETE FROM zfi_a_intrc_cpd WHERE id EQ @i_uuid.
    DELETE FROM zfi_a_intrc_cpdl WHERE id EQ @i_uuid.
    UPDATE zfi_a_intrc_cph SET isdeleted = @abap_false, status = @space WHERE id EQ @i_uuid.
    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.
