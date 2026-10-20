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

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: exponer el resultado del paralelizador
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12k: retirar diagnóstico adicional
    " DATA error_text TYPE string READ-ONLY.
    " Fin EXT_OSCUGALD 16.10.2026 - C12k
    " Fin EXT_OSCUGALD 07.10.2026 - C12

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



CLASS zcl_interco_class_engine_mult IMPLEMENTATION.


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

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 08.10.2026 - C12s: histórico RUN anterior a C12l
    " Copia del RUN de C12k recuperada de fuente DS4 releída antes de C12l.
    " Todo el método siguiente se conserva como comentario.
    "   METHOD run.
    " ***    SELECT name, low FROM zi_tvarvc
    " ***    WHERE name IN ( 'ZINTERCO_IC05_TASKS',
    " ***                    'ZINTERCO_IC05_PERCENTAGE' )
    " ***    INTO TABLE @DATA(params).
    " ***
    " ***    IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
    " ***      DATA(tasks) =  CONV int4(  params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
    " ***    ELSE.
    " ***      tasks = 10.
    " ***    ENDIF.
    " ***
    " ***    IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
    " ***      DATA(percentage) =  CONV int4(  params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
    " ***    ELSE.
    " ***      percentage = 20.
    " ***    ENDIF.
    " ***
    " ***    FINAL(parallel) = NEW cl_abap_parallel(
    " ***            p_percentage   = percentage
    " ***        p_num_tasks    = tasks
    " ***        p_local_server = abap_true
    " ***    ).
    " ***    DATA instances TYPE cl_abap_parallel=>t_in_inst_tab.
    " ***
    " ***
    " ***    LOOP AT selections REFERENCE INTO DATA(selection).
    " ***      DATA(instance) = NEW lcl_parallel_processing( selection->* ).
    " ***      APPEND instance TO instances.
    " ***    ENDLOOP.
    " ***
    " ***    parallel->run_inst(
    " ***      EXPORTING
    " ***        p_in_tab = instances ).
    "
    "     " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    "     " C12, paso 6c.3: recuperar errores de las instancias paralelas
    "     CLEAR error_text.
    "
    "     SELECT name, low FROM zi_tvarvc
    "       WHERE name IN ( 'ZINTERCO_IC05_TASKS',
    "                       'ZINTERCO_IC05_PERCENTAGE' )
    "       INTO TABLE @DATA(params).
    "
    "     IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
    "       DATA(tasks) = CONV int4(
    "         params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
    "     ELSE.
    "       tasks = 10.
    "     ENDIF.
    "
    "     IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
    "       DATA(percentage) = CONV int4(
    "         params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
    "     ELSE.
    "       percentage = 20.
    "     ENDIF.
    "
    "     FINAL(parallel) = NEW cl_abap_parallel(
    "       p_percentage   = percentage
    "       p_num_tasks    = tasks
    "       p_local_server = abap_true ).
    "
    "     DATA instances TYPE cl_abap_parallel=>t_in_inst_tab.
    "
    "     LOOP AT selections REFERENCE INTO DATA(selection).
    "       DATA(worker_instance) =
    "         NEW lcl_parallel_processing( selection->* ).
    "       APPEND worker_instance TO instances.
    "     ENDLOOP.
    "
    "     " Código anterior conservado:
    "     " parallel->run_inst(
    "     "   EXPORTING
    "     "     p_in_tab = instances ).
    "
    "     DATA worker_results TYPE cl_abap_parallel=>t_out_inst_tab.
    "
    "     TRY.
    "         parallel->run_inst(
    "           EXPORTING
    "             p_in_tab = instances
    "           IMPORTING
    "             p_out_tab = worker_results ).
    "
    "       CATCH cx_root.
    "         error_text =
    "           'No se pudieron recuperar los resultados de la clasificación paralela.'.
    "         RETURN instance.
    "     ENDTRY.
    "
    "     DATA error_count TYPE i.
    "     DATA worker TYPE REF TO lcl_parallel_processing.
    "
    "     LOOP AT worker_results REFERENCE INTO DATA(worker_result).
    "
    "       IF worker_result->inst IS NOT BOUND.
    "         error_count = error_count + 1.
    "         CONTINUE.
    "       ENDIF.
    "
    "       CLEAR worker.
    "       worker ?= worker_result->inst.
    "
    "       IF worker IS NOT BOUND.
    "         error_count = error_count + 1.
    "         CONTINUE.
    "       ENDIF.
    "
    "       IF worker->error_text IS NOT INITIAL.
    "         error_count = error_count + 1.
    "
    "         IF error_text IS INITIAL.
    "           error_text = worker->error_text.
    "         ENDIF.
    "       ENDIF.
    "
    "     ENDLOOP.
    "
    "     IF lines( worker_results ) <> lines( instances )
    "        AND error_count = 0.
    "       error_count = 1.
    "     ENDIF.
    "
    "     IF error_count > 0.
    "       IF error_text IS INITIAL.
    "         error_text =
    "           'Una o más clasificaciones paralelas no devolvieron resultado.'.
    "       ENDIF.
    "
    "       error_text =
    "         |{ error_text } Corridas con error: { error_count }.|.
    "     ENDIF.
    "
    "     RETURN instance.
    "     " Fin EXT_OSCUGALD 07.10.2026 - C12
    "
    "   ENDMETHOD.
    " Fin EXT_OSCUGALD 08.10.2026 - C12s
***    SELECT name, low FROM zi_tvarvc
***    WHERE name IN ( 'ZINTERCO_IC05_TASKS',
***                    'ZINTERCO_IC05_PERCENTAGE' )
***    INTO TABLE @DATA(params).
***
***    IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
***      DATA(tasks) =  CONV int4(  params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
***    ELSE.
***      tasks = 10.
***    ENDIF.
***
***    IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
***      DATA(percentage) =  CONV int4(  params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
***    ELSE.
***      percentage = 20.
***    ENDIF.
***
***    FINAL(parallel) = NEW cl_abap_parallel(
***            p_percentage   = percentage
***        p_num_tasks    = tasks
***        p_local_server = abap_true
***    ).
***    DATA instances TYPE cl_abap_parallel=>t_in_inst_tab.
***
***
***    LOOP AT selections REFERENCE INTO DATA(selection).
***      DATA(instance) = NEW lcl_parallel_processing( selection->* ).
***      APPEND instance TO instances.
***    ENDLOOP.
***
***    parallel->run_inst(
***      EXPORTING
***        p_in_tab = instances ).

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12, paso 6c.3: recuperar errores de las instancias paralelas
    " C12k 16.10.2026: código sustituido conservado.
    " CLEAR error_text.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12l: cola vacía
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12l: retirar control adicional
    " IF selections IS INITIAL.
    " RETURN instance.
    " ENDIF.
    " Fin EXT_OSCUGALD 16.10.2026 - C12l
    " Fin EXT_OSCUGALD 07.10.2026 - C12l

    SELECT name, low FROM zi_tvarvc
      WHERE name IN ( 'ZINTERCO_IC05_TASKS',
                      'ZINTERCO_IC05_PERCENTAGE' )
      INTO TABLE @DATA(params).

    IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
      DATA(tasks) = CONV int4(
        params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
    ELSE.
      tasks = 10.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
      DATA(percentage) = CONV int4(
        params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
    ELSE.
      percentage = 20.
    ENDIF.

    FINAL(parallel) = NEW cl_abap_parallel(
      p_percentage   = percentage
      p_num_tasks    = tasks
      p_local_server = abap_true ).

    DATA instances TYPE cl_abap_parallel=>t_in_inst_tab.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12l: workers únicos
    " LOOP anterior conservado: programaba también selecciones repetidas.
    " LOOP AT selections REFERENCE INTO DATA(selection).
    "   DATA(worker_instance) =
    "     NEW lcl_parallel_processing( selection->* ).
    "   APPEND worker_instance TO instances.
    " ENDLOOP.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12l: restituir planificación original
    " DATA scheduled_selections TYPE HASHED TABLE OF ty_selection
    " WITH UNIQUE KEY companycode fiscalyear fiscalperiod ledger paymenttype.

    " Recorrer la cola en su orden actual; conservar el tipo solicitado.
    " LOOP AT selections REFERENCE INTO DATA(selection).
    " INSERT selection->* INTO TABLE scheduled_selections.
    " IF sy-subrc <> 0.
    " CONTINUE.
    " ENDIF.

    " DATA(worker_instance) =
    " NEW lcl_parallel_processing( selection->* ).
    " APPEND worker_instance TO instances.
    " ENDLOOP.

    " Los workers ya contienen sus selecciones.
    " Consumir la cola antes del lanzamiento, incluso si run_inst falla.
    " Un reintento debe programarse nuevamente mediante FOR.
    " CLEAR selections.

    LOOP AT selections REFERENCE INTO DATA(selection).
      DATA(instance) = NEW lcl_parallel_processing( selection->* ).
      APPEND instance TO instances.
    ENDLOOP.
    " Fin EXT_OSCUGALD 16.10.2026 - C12l
    " Fin EXT_OSCUGALD 07.10.2026 - C12l

    " Código anterior conservado:
    " parallel->run_inst(
    "   EXPORTING
    "     p_in_tab = instances ).

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 16.10.2026 - C12k: restituir llamada original
    " DATA worker_results TYPE cl_abap_parallel=>t_out_inst_tab.

    " TRY.
    " parallel->run_inst(
    " EXPORTING
    " p_in_tab = instances
    " IMPORTING
    " p_out_tab = worker_results ).

    " CATCH cx_root.
    " error_text =
    " 'No se pudieron recuperar los resultados de la clasificación paralela.'.
    " RETURN instance.
    " ENDTRY.

    " DATA error_count TYPE i.
    " DATA worker TYPE REF TO lcl_parallel_processing.

    " LOOP AT worker_results REFERENCE INTO DATA(worker_result).

    " IF worker_result->inst IS NOT BOUND.
    " error_count = error_count + 1.
    " CONTINUE.
    " ENDIF.

    " CLEAR worker.
    " worker ?= worker_result->inst.

    " IF worker IS NOT BOUND.
    " error_count = error_count + 1.
    " CONTINUE.
    " ENDIF.

    " IF worker->error_text IS NOT INITIAL.
    " error_count = error_count + 1.

    " IF error_text IS INITIAL.
    " error_text = worker->error_text.
    " ENDIF.
    " ENDIF.

    " ENDLOOP.

    " IF lines( worker_results ) <> lines( instances )
    " AND error_count = 0.
    " error_count = 1.
    " ENDIF.

    " IF error_count > 0.
    " IF error_text IS INITIAL.
    " error_text =
    " 'Una o más clasificaciones paralelas no devolvieron resultado.'.
    " ENDIF.

    " error_text =
    " |{ error_text } Corridas con error: { error_count }.|.
    " ENDIF.

    " RETURN instance.

    parallel->run_inst(
      EXPORTING
        p_in_tab = instances ).
    " Fin EXT_OSCUGALD 16.10.2026 - C12k
    " Fin EXT_OSCUGALD 07.10.2026 - C12

  ENDMETHOD.

ENDCLASS.

