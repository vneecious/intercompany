*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
***class lcl_parallel_processing definition create public.
***
***  public section.
***
***
***    interfaces: if_abap_parallel.
***
***    methods:
***      constructor
***        importing
***          i_selection type zcl_interco_class_engine_mult=>ty_selection.
***
***  private section.
***    data selection type  zcl_interco_class_engine_mult=>ty_selection.
***
***endclass.
***
***
***class lcl_parallel_processing implementation.
***
***  method constructor.
***    selection = i_selection.
***  endmethod.
***
***  method if_abap_parallel~do.
***
***
***    zcl_interco_class_engine=>new( )->for(
***        i_companycode = selection-companycode
***        i_fiscalperiod = selection-fiscalperiod
***        i_fiscalyear = selection-fiscalyear
***        i_ledger = selection-ledger
***        i_paymenttype = selection-paymenttype
***    )->run(  ).
***
***
***  endmethod.
***
***endclass.
class lcl_parallel_processing definition create public.

  public section.

    interfaces if_abap_parallel.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: devolver el estado serializado del worker
    DATA error_text TYPE string READ-ONLY.
    " Fin EXT_OSCUGALD 07.10.2026 - C12

    methods:
      constructor
        importing
          i_selection type zcl_interco_class_engine_mult=>ty_selection.

  private section.

    data selection type
      zcl_interco_class_engine_mult=>ty_selection.

endclass.


class lcl_parallel_processing implementation.

  method constructor.
    selection = i_selection.
  endmethod.


  method if_abap_parallel~do.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: conservar el error devuelto por RUN
    CLEAR error_text.

    TRY.
        DATA(engine) = zcl_interco_class_engine=>new( )->for(
          i_companycode  = selection-companycode
          i_fiscalperiod = selection-fiscalperiod
          i_fiscalyear   = selection-fiscalyear
          i_ledger       = selection-ledger
          i_paymenttype  = selection-paymenttype ).

        engine->run( ).
        error_text = engine->error_text.

      CATCH cx_root.
        error_text =
          'No se pudo completar una clasificación paralela.'.
    ENDTRY.
    " Fin EXT_OSCUGALD 07.10.2026 - C12

  endmethod.

endclass.
