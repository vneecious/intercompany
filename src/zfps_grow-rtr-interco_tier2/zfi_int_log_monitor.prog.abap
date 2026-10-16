*&---------------------------------------------------------------------*
*& Report ZFI_INT_LOG_MONITOR
*&---------------------------------------------------------------------*
*& Monitor de Log - Intereses por Mora Intercompany MLA
*& Ticket: SDFPSINIC-23382
*& Autor:  EXT_AGFAGINA
*&---------------------------------------------------------------------*
REPORT zfi_int_log_monitor LINE-SIZE 255.

*----------------------------------------------------------------------*
* TYPES
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_log,
    log_id            TYPE zfint_post_log-log_id,
    run_id            TYPE zfint_post_log-run_id,
    run_status        TYPE zfint_post_log-run_status,
    doc_status        TYPE zfint_post_log-doc_status,
    severity          TYPE zfint_post_log-severity,
    bukrs             TYPE zfint_post_log-bukrs,
    vbund             TYPE zfint_post_log-vbund,
    concepto          TYPE zfint_post_log-concepto,
    doc_no            TYPE zfint_post_log-doc_no,
    source_belnr      TYPE zfint_post_log-source_belnr,
    source_gjahr      TYPE zfint_post_log-source_gjahr,
    cons_belnr        TYPE zfint_post_log-cons_belnr,
    cons_gjahr        TYPE zfint_post_log-cons_gjahr,
    int_curr          TYPE zfint_post_log-int_curr,
    int_amount        TYPE zfint_post_log-int_amount,
    dias_mora         TYPE zfint_post_log-dias_mora,
    msg_text          TYPE zfint_post_log-msg_text,
    msgid             TYPE zfint_post_log-msgid,
    msgno             TYPE zfint_post_log-msgno,
    intrun_id         TYPE zfint_post_log-intrun_id,
    cons_generation   TYPE zfint_post_log-cons_generation,
    parent_cons_belnr TYPE zfint_post_log-parent_cons_belnr,
    cancel_belnr      TYPE zfint_post_log-cancel_belnr,
    erdat             TYPE zfint_post_log-erdat,
    erzet             TYPE zfint_post_log-erzet,
    ernam             TYPE zfint_post_log-ernam,
  END OF ty_log,
  tt_log TYPE STANDARD TABLE OF ty_log.

*----------------------------------------------------------------------*
* DATA
*----------------------------------------------------------------------*
DATA:
  lt_log TYPE tt_log,
  ls_log TYPE ty_log.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b001 WITH FRAME TITLE TEXT-b01.
  PARAMETERS:
    p_bukrs TYPE bukrs MEMORY ID buk.
  SELECT-OPTIONS:
    s_runst FOR ls_log-run_status,
    s_docst FOR ls_log-doc_status,
    s_sev   FOR ls_log-severity,
    s_vbund FOR ls_log-vbund,
    s_runid FOR ls_log-run_id,
    s_erdat FOR ls_log-erdat.
SELECTION-SCREEN END OF BLOCK b001.

SELECTION-SCREEN BEGIN OF BLOCK b002 WITH FRAME TITLE TEXT-b02.
  PARAMETERS:
    p_max TYPE i DEFAULT 5000.
SELECTION-SCREEN END OF BLOCK b002.

*----------------------------------------------------------------------*
* INITIALIZATION
*----------------------------------------------------------------------*
INITIALIZATION.
  " Defaults: ultimos 90 dias
  s_erdat-sign   = 'I'.
  s_erdat-option = 'BT'.
  s_erdat-low    = sy-datum - 90.
  s_erdat-high   = sy-datum.
  APPEND s_erdat.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.

  AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
    ID 'ACTVT' FIELD '03'
    ID 'BUKRS' FIELD p_bukrs.
  IF sy-subrc <> 0.
    MESSAGE e800(fr) WITH p_bukrs.
  ENDIF.

  " Orden aplicado directamente en SELECT - no se necesita sorting en ALV
  SELECT log_id, run_id, run_status, doc_status, severity,
         bukrs, vbund, concepto, doc_no,
         source_belnr, source_gjahr, cons_belnr, cons_gjahr,
         int_curr, int_amount, dias_mora, msg_text, msgid, msgno,
         intrun_id, cons_generation, parent_cons_belnr, cancel_belnr,
         erdat, erzet, ernam
    FROM zfint_post_log
    INTO CORRESPONDING FIELDS OF TABLE @lt_log
    UP TO @p_max ROWS
    WHERE bukrs      = @p_bukrs
      AND run_status IN @s_runst
      AND doc_status IN @s_docst
      AND severity   IN @s_sev
      AND vbund      IN @s_vbund
      AND run_id     IN @s_runid
      AND erdat      IN @s_erdat
    ORDER BY erdat DESCENDING, erzet DESCENDING, run_id ASCENDING.

  IF sy-subrc <> 0 OR lt_log IS INITIAL.
    MESSAGE s000(0k) WITH 'No se encontraron registros para los criterios seleccionados.'.
    STOP.
  ENDIF.

*----------------------------------------------------------------------*
* END-OF-SELECTION
*----------------------------------------------------------------------*
END-OF-SELECTION.

  PERFORM display_alv.

*----------------------------------------------------------------------*
* FORM: DISPLAY_ALV - CL_SALV_TABLE
*----------------------------------------------------------------------*
FORM display_alv.

  DATA: lo_salv    TYPE REF TO cl_salv_table,
        lo_cols    TYPE REF TO cl_salv_columns_table,
        lo_col     TYPE REF TO cl_salv_column_table,
        lo_display TYPE REF TO cl_salv_display_settings,
        lo_funcs   TYPE REF TO cl_salv_functions_list.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_salv
        CHANGING
          t_table      = lt_log ).
    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
      RETURN.
  ENDTRY.

  " Funciones estandar
  lo_funcs = lo_salv->get_functions( ).
  lo_funcs->set_all( abap_true ).

  " Display settings
  lo_display = lo_salv->get_display_settings( ).
  lo_display->set_striped_pattern( abap_true ).
  lo_display->set_fit_column_to_table_size( abap_true ).

  " Columnas
  lo_cols = lo_salv->get_columns( ).
  lo_cols->set_optimize( abap_true ).

  TRY.
      lo_col ?= lo_cols->get_column( 'ERDAT' ).
      lo_col->set_medium_text( 'Fecha' ).
      lo_col->set_output_length( 10 ).

      lo_col ?= lo_cols->get_column( 'ERZET' ).
      lo_col->set_medium_text( 'Hora' ).
      lo_col->set_output_length( 8 ).

      lo_col ?= lo_cols->get_column( 'RUN_ID' ).
      lo_col->set_medium_text( 'Run ID' ).
      lo_col->set_output_length( 20 ).

      lo_col ?= lo_cols->get_column( 'RUN_STATUS' ).
      lo_col->set_medium_text( 'Run Status' ).
      lo_col->set_output_length( 4 ).

      lo_col ?= lo_cols->get_column( 'DOC_STATUS' ).
      lo_col->set_medium_text( 'Doc Status' ).
      lo_col->set_output_length( 4 ).

      lo_col ?= lo_cols->get_column( 'SEVERITY' ).
      lo_col->set_medium_text( 'Sev' ).
      lo_col->set_output_length( 3 ).

      lo_col ?= lo_cols->get_column( 'BUKRS' ).
      lo_col->set_medium_text( 'Sociedad' ).
      lo_col->set_key( abap_true ).

      lo_col ?= lo_cols->get_column( 'VBUND' ).
      lo_col->set_medium_text( 'Trading Partner' ).
      lo_col->set_output_length( 8 ).

      lo_col ?= lo_cols->get_column( 'CONCEPTO' ).
      lo_col->set_medium_text( 'Concepto' ).
      lo_col->set_output_length( 20 ).

      lo_col ?= lo_cols->get_column( 'DOC_NO' ).
      lo_col->set_medium_text( 'Doc FI' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'SOURCE_BELNR' ).
      lo_col->set_medium_text( 'Doc Origen' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'SOURCE_GJAHR' ).
      lo_col->set_medium_text( 'Ej.Orig' ).
      lo_col->set_output_length( 6 ).

      lo_col ?= lo_cols->get_column( 'CONS_BELNR' ).
      lo_col->set_medium_text( 'Doc Consol.' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'CONS_GJAHR' ).
      lo_col->set_medium_text( 'Ej.Cons.' ).
      lo_col->set_output_length( 6 ).

      lo_col ?= lo_cols->get_column( 'INT_CURR' ).
      lo_col->set_medium_text( 'Mon.' ).
      lo_col->set_output_length( 5 ).

      lo_col ?= lo_cols->get_column( 'INT_AMOUNT' ).
      lo_col->set_medium_text( 'Importe Int.' ).
      lo_col->set_output_length( 18 ).

      lo_col ?= lo_cols->get_column( 'DIAS_MORA' ).
      lo_col->set_medium_text( 'Dias Mora' ).
      lo_col->set_output_length( 8 ).

      lo_col ?= lo_cols->get_column( 'CONS_GENERATION' ).
      lo_col->set_medium_text( 'Gen.' ).
      lo_col->set_output_length( 4 ).

      lo_col ?= lo_cols->get_column( 'MSG_TEXT' ).
      lo_col->set_medium_text( 'Mensaje' ).
      lo_col->set_output_length( 60 ).

      lo_col ?= lo_cols->get_column( 'MSGID' ).
      lo_col->set_medium_text( 'Class Msg' ).
      lo_col->set_output_length( 10 ).

      lo_col ?= lo_cols->get_column( 'MSGNO' ).
      lo_col->set_medium_text( 'Nr.Msg' ).
      lo_col->set_output_length( 4 ).

      lo_col ?= lo_cols->get_column( 'INTRUN_ID' ).
      lo_col->set_medium_text( 'Int.Run ID' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'PARENT_CONS_BELNR' ).
      lo_col->set_medium_text( 'Doc Padre' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'CANCEL_BELNR' ).
      lo_col->set_medium_text( 'Doc Cancel.' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'ERNAM' ).
      lo_col->set_medium_text( 'Usuario' ).
      lo_col->set_output_length( 12 ).

      lo_col ?= lo_cols->get_column( 'LOG_ID' ).
      lo_col->set_medium_text( 'Log ID' ).
      lo_col->set_output_length( 32 ).

    CATCH cx_salv_not_found.
      " columna no encontrada - continuar
  ENDTRY.

  lo_salv->display( ).

ENDFORM.
