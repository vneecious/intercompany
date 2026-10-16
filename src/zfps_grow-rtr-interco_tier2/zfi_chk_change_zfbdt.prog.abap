*&---------------------------------------------------------------------*
*& Report  ZFI_CHK_CHANGE_ZFBDT
*&---------------------------------------------------------------------*
*& Modifica ZFBDT (Baseline Date) en documentos FI contabilizados.
*& Ticket: SDFPSINIC-23382 - Intereses por Mora Intercompany MLA
*& v4.0: El cambio masivo usa el metodo change_base_date_direct de
*&       ZCL_FI_ITEMS_CHANGE_ZFBDT (replica del estandar
*&       RFVD_CHK_CHANGE_CLEARING: UPDATE directo BSEG/ACDOCA + change
*&       documents + delta BW). Validacion total previa y grabacion
*&       all-or-nothing en 1 LUW. Salida en ALV. Reemplaza al motor BDC
*&       change_base_date (FI_ITEMS_MASS_CHANGE).
*& v5.0: SELECT-OPTIONS S_BELNR/S_BLART/S_BUZEI reemplazados por
*&       PARAMETERS P_BELNR/P_BLART/P_BUZEI para habilitar la carga
*&       masiva via LSMW (los SELECT-OPTIONS generan campos dynpro
*&       auxiliares con '%' que el Field Mapping de LSMW no expone).
*&       Los rangos se construyen en START-OF-SELECTION. El codigo v4.0
*&       queda comentado en cada punto modificado, para trazabilidad.
*&---------------------------------------------------------------------*
REPORT zfi_chk_change_zfbdt MESSAGE-ID fb LINE-SIZE 132.

* --- v4.0 (comentado - trazabilidad, no borrar) ----------------------*
* Variables auxiliares de los SELECT-OPTIONS (FOR), sin uso en v5.0
*DATA: lv_belnr TYPE bseg-belnr,
*      lv_buzei TYPE bseg-buzei,
*      lv_blart TYPE bkpf-blart.
*---------------------------------------------------------------------*
* v5.0: rangos construidos en codigo, tipados con la interfaz del motor
DATA: s_belnr TYPE zif_fi_items_change_zfbdt=>ty_r_belnr,
      s_blart TYPE zif_fi_items_change_zfbdt=>ty_r_blart,
      s_buzei TYPE zif_fi_items_change_zfbdt=>ty_r_buzei.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b001 WITH FRAME.
  PARAMETERS:
    p_bukrs TYPE bukrs MEMORY ID buk OBLIGATORY,
    p_gjahr TYPE gjahr MEMORY ID gjr OBLIGATORY.
* --- v4.0 (comentado - trazabilidad, no borrar) ----------------------*
*  SELECT-OPTIONS:
*    s_belnr FOR lv_belnr,
*    s_blart FOR lv_blart,
*    s_buzei FOR lv_buzei DEFAULT '01'.
*---------------------------------------------------------------------*
  PARAMETERS:
    p_belnr TYPE bseg-belnr,
    p_blart TYPE bkpf-blart,
    p_buzei TYPE bseg-buzei DEFAULT '01',
    p_zfbdt TYPE dzfbdt.
SELECTION-SCREEN END OF BLOCK b001.

SELECTION-SCREEN BEGIN OF BLOCK b002 WITH FRAME.
  PARAMETERS:
    p_update TYPE xfeld AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK b002.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN - confirmacion antes de ejecutar el update real
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF p_update = abap_true.
    DATA lv_answer TYPE c LENGTH 1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Confirmacion de actualizacion'
        text_question         = 'Se actualizara el campo Fecha Base (ZFBDT) de los documentos seleccionados. Desea continuar?'
        text_button_1         = 'Si'
        text_button_2         = 'No'
        default_button        = '2'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    IF lv_answer <> '1'.
      MESSAGE 'Actualizacion cancelada por el usuario.' TYPE 'E'.
    ENDIF.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.

  AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
    ID 'ACTVT' FIELD '02'
    ID 'BUKRS' FIELD p_bukrs.
  IF sy-subrc <> 0.
    MESSAGE e800(fr) WITH p_bukrs.
  ENDIF.

* v5.0: construccion de los rangos a partir de los PARAMETERS.
* La guarda IS NOT INITIAL es obligatoria: cargar una fila con LOW vacio
* convierte el filtro en "campo = espacios" (no matchea ningun documento)
* en lugar de "sin restriccion". Tabla de rangos vacia = sin filtro.
  IF p_belnr IS NOT INITIAL.
    s_belnr = VALUE #( ( sign = 'I' option = 'EQ' low = p_belnr ) ).
  ENDIF.
  IF p_blart IS NOT INITIAL.
    s_blart = VALUE #( ( sign = 'I' option = 'EQ' low = p_blart ) ).
  ENDIF.
  IF p_buzei IS NOT INITIAL.
    s_buzei = VALUE #( ( sign = 'I' option = 'EQ' low = p_buzei ) ).
  ENDIF.

  DATA(lo_change) = zcl_fi_items_change_zfbdt=>get_instance( ).

  " Validacion de sociedad (metodo de la clase)
  IF lo_change->company_code_exists( p_bukrs ) = abap_false.
    MESSAGE e001(fb) WITH p_bukrs DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Seleccion de documentos + ZFBDT (metodo de la clase)
* --- v4.0 (comentado - trazabilidad, no borrar) ----------------------*
*  DATA(lt_keys) = lo_change->select_items(
*                    iv_bukrs = p_bukrs
*                    iv_gjahr = p_gjahr
*                    it_belnr = s_belnr[]
*                    it_blart = s_blart[]
*                    it_buzei = s_buzei[] ).
*---------------------------------------------------------------------*
  DATA(lt_keys) = lo_change->select_items(
                    iv_bukrs = p_bukrs
                    iv_gjahr = p_gjahr
                    it_belnr = s_belnr
                    it_blart = s_blart
                    it_buzei = s_buzei ).

  IF lt_keys IS INITIAL.
    MESSAGE 'No se encontraron documentos/posiciones para los criterios seleccionados.' TYPE 'S' DISPLAY LIKE 'I'.
    RETURN.
  ENDIF.

  " Motor directo (replica RFVD): valida todo y graba all-or-nothing en 1 LUW
  DATA lt_result TYPE zif_fi_items_change_zfbdt=>ty_t_result.

  TRY.
      lt_result = lo_change->change_base_date_direct(
                    it_items  = lt_keys
                    iv_zfbdt  = p_zfbdt
                    iv_update = p_update ).
    CATCH zcx_mora_post_error INTO DATA(lx_change).
      MESSAGE lx_change->get_error_text( ) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  " Salida ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = DATA(lo_alv)
        CHANGING  t_table      = lt_result ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_display_settings( )->set_list_header( 'Modificacion ZFBDT - Documentos FI' ).
      lo_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
