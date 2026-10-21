"! <p>Executes classifications in parallel for all periods less than or equal to the provided period.</p>
CLASS zcl_interco_class_engine_mult DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.

    TYPES: BEGIN OF ty_selection,
             companycode  TYPE zi_intercojeitempandl-companycode,
             fiscalyear   TYPE zi_intercojeitempandl-fiscalyear,
             fiscalperiod TYPE zi_intercojeitempandl-fiscalperiod,
             paymenttype  TYPE zi_intercojeitempandl-paymenttype,
             ledger       TYPE zi_intercojeitempandl-ledger,
           END OF ty_selection.

    CLASS-METHODS:
      new
        RETURNING VALUE(results) TYPE REF TO zcl_interco_class_engine_mult.

    METHODS:
      for
        IMPORTING
                  i_companycode  TYPE zi_intercojeitempandl-companycode
                  i_fiscalyear   TYPE zi_intercojeitempandl-fiscalyear
                  i_fiscalperiod TYPE zi_intercojeitempandl-fiscalperiod
                  i_paymenttype  TYPE zi_intercojeitempandl-paymenttype
                  i_ledger       TYPE zi_intercojeitempandl-ledger
        RETURNING VALUE(result)  TYPE REF TO zcl_interco_class_engine_mult.

    METHODS:
      run
        RETURNING VALUE(result) TYPE REF TO zcl_interco_class_engine_mult.

  PRIVATE SECTION.
    CLASS-DATA: instance TYPE REF TO zcl_interco_class_engine_mult.

    DATA selections TYPE TABLE OF ty_selection.

ENDCLASS.



CLASS ZCL_INTERCO_CLASS_ENGINE_MULT IMPLEMENTATION.


  METHOD new.
    IF instance IS NOT BOUND.
      instance = NEW #( ).
    ENDIF.
    RETURN instance.
  ENDMETHOD.


  METHOD for.

    DATA(current_period) = i_fiscalperiod.

    WHILE current_period > 0.
      APPEND INITIAL LINE TO selections REFERENCE INTO DATA(selection).
      selection->companycode = i_companycode.
      selection->fiscalperiod = current_period.
      selection->fiscalyear = i_fiscalyear.
      selection->ledger = i_ledger.
      selection->paymenttype = i_paymenttype.
      current_period -= 1.
    ENDWHILE.
    SORT selections BY fiscalperiod ASCENDING .

    RETURN instance.


  ENDMETHOD.


  METHOD run.
    SELECT name, low FROM zi_tvarvc
    WHERE name IN ( 'ZINTERCO_IC05_TASKS',
                    'ZINTERCO_IC05_PERCENTAGE' )
    INTO TABLE @DATA(params).

    IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
      DATA(tasks) =  CONV int4(  params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
    ELSE.
      tasks = 10.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
      DATA(percentage) =  CONV int4(  params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
    ELSE.
      percentage = 20.
    ENDIF.

    FINAL(parallel) = NEW cl_abap_parallel(
            p_percentage   = percentage
        p_num_tasks    = tasks
        p_local_server = abap_true
    ).
    DATA instances TYPE cl_abap_parallel=>t_in_inst_tab.


    LOOP AT selections REFERENCE INTO DATA(selection).
      DATA(instance) = NEW lcl_parallel_processing( selection->* ).
      APPEND instance TO instances.
    ENDLOOP.

    parallel->run_inst(
      EXPORTING
        p_in_tab = instances ).

  ENDMETHOD.
ENDCLASS.
