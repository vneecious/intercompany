CLASS zcl_intercoproposalevents DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS applyMetric
        IMPORTING iv_proposal_id type uuid.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCOPROPOSALEVENTS IMPLEMENTATION.


  METHOD applymetric.

    check iv_proposal_id is not INITIAL.

    SELECT id, fiscalperiod, fiscalyear,
    providercompanycode, product, status,
    intercobasisid, globalcurrency, amountinglobalcurrency,
    createdby, createdat, isdeleted
        FROM zfi_a_intrc_cph
        WHERE id = @iv_proposal_id
        into table @DATA(ls_proposal).


    IF sy-subrc = 0.

*       ls_proposal-status = 'S'.

       "modify zfi_a_intrc_cph from @ls_proposal.
       MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
        UPDATE FIELDS ( status )
        WITH CORRESPONDING #( ls_proposal )
        REPORTED  DATA(lt_reported).

    endif.

  ENDMETHOD.
ENDCLASS.
