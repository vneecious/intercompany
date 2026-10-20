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
CLASS lcl_parallel_processing DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_abap_parallel.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: devolver el estado serializado del worker
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12k: retirar diagnóstico adicional
    " DATA error_text TYPE string READ-ONLY.
    " Fin EXT_OSCUGALD 16.10.2026 - C12k
    " Fin EXT_OSCUGALD 07.10.2026 - C12

    METHODS:
      constructor
        IMPORTING
          i_selection TYPE zcl_interco_class_engine_mult=>ty_selection.

  PRIVATE SECTION.

    DATA selection TYPE
      zcl_interco_class_engine_mult=>ty_selection.

ENDCLASS.


CLASS lcl_parallel_processing IMPLEMENTATION.

  METHOD constructor.
    selection = i_selection.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: conservar el error devuelto por RUN
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12k: restituir worker original
    " CLEAR error_text.

    " TRY.
    " DATA(engine) = zcl_interco_class_engine=>new( )->for(
    " i_companycode  = selection-companycode
    " i_fiscalperiod = selection-fiscalperiod
    " i_fiscalyear   = selection-fiscalyear
    " i_ledger       = selection-ledger
    " i_paymenttype  = selection-paymenttype ).

    " engine->run( ).
    " error_text = engine->error_text.

    " CATCH cx_root.
    " error_text =
    " 'No se pudo completar una clasificación paralela.'.
    " ENDTRY.

    zcl_interco_class_engine=>new( )->for(
        i_companycode = selection-companycode
        i_fiscalperiod = selection-fiscalperiod
        i_fiscalyear = selection-fiscalyear
        i_ledger = selection-ledger
        i_paymenttype = selection-paymenttype
    )->run(  ).
    " Fin EXT_OSCUGALD 16.10.2026 - C12k
    " Fin EXT_OSCUGALD 07.10.2026 - C12

  ENDMETHOD.

ENDCLASS.
