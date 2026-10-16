CLASS zcl_fi_items_change_zfbdt DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    INTERFACES zif_fi_items_change_zfbdt.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO zif_fi_items_change_zfbdt.

  PRIVATE SECTION.
    TYPES tt_bseg TYPE STANDARD TABLE OF bseg WITH DEFAULT KEY.

    CONSTANTS c_tvarvc_bseg   TYPE tvarvc-name VALUE 'ZFI_ZFBDT_TAB_BSEG'.
    CONSTANTS c_tvarvc_acdoca TYPE tvarvc-name VALUE 'ZFI_ZFBDT_TAB_ACDOCA'.
    CONSTANTS c_tvarvc_fm_bw  TYPE tvarvc-name VALUE 'ZFI_ZFBDT_FM_BWDELTA'.

    CLASS-DATA go_instance TYPE REF TO zif_fi_items_change_zfbdt.

    "! Genera change documents (objeto BELEG) por documento - replica RFVD
    METHODS change_documents
      IMPORTING it_bseg_old     TYPE tt_bseg
                it_bseg_new     TYPE tt_bseg
      RETURNING VALUE(rv_error) TYPE abap_bool.

ENDCLASS.



CLASS zcl_fi_items_change_zfbdt IMPLEMENTATION.


  METHOD get_instance.
    IF go_instance IS INITIAL.
      go_instance = NEW zcl_fi_items_change_zfbdt( ).
    ENDIF.
    ro_instance = go_instance.
  ENDMETHOD.


  METHOD zif_fi_items_change_zfbdt~company_code_exists.
    SELECT SINGLE companycode
      FROM i_companycode
      WHERE companycode = @iv_bukrs
      INTO @DATA(lv_bukrs).
    rv_exists = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_fi_items_change_zfbdt~select_items.
    " Lectura de documentos + ZFBDT via CDS liberadas (sucesores de BKPF/BSEG).
    " DueCalculationBaseDate = ZFBDT.
    SELECT hdr~companycode             AS bukrs,
           hdr~accountingdocument      AS belnr,
           hdr~fiscalyear              AS gjahr,
           item~accountingdocumentitem AS buzei,
           item~duecalculationbasedate AS zfbdt
      FROM i_journalentry AS hdr
      INNER JOIN i_operationalacctgdocitem AS item
        ON  item~companycode        = hdr~companycode
        AND item~accountingdocument = hdr~accountingdocument
        AND item~fiscalyear         = hdr~fiscalyear
      WHERE hdr~companycode             = @iv_bukrs
        AND hdr~fiscalyear              = @iv_gjahr
        AND hdr~accountingdocument      IN @it_belnr
        AND hdr~accountingdocumenttype  IN @it_blart
        AND item~accountingdocumentitem IN @it_buzei
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_fi_items_change_zfbdt~change_base_date.
    " Encapsula el FM interno FI_ITEMS_MASS_CHANGE (delega en FB02 via BDC:
    " respeta TBAER, change documents y LUW). Unica dependencia con el FM
    " interno - excepcion Clean Core aislada en este metodo. Nota SAP 2431747.
    DATA: ls_bseg_template TYPE bseg,
          lt_fldtab        TYPE tpit_t_fname,
          ls_fldtab        TYPE tpit_fname,
          lt_buztab        TYPE tpit_t_buztab,
          ls_buztab        TYPE tpit_buztab,
          lt_errtab        TYPE tpit_t_errdoc.

    CLEAR et_errors.

    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_zfbdt IS INITIAL.
      RAISE EXCEPTION TYPE zcx_mora_post_error
        EXPORTING iv_msg_text = 'ZFBDT inicial: no se puede actualizar la fecha base'.
    ENDIF.

    ls_fldtab-fname = 'ZFBDT'.
    APPEND ls_fldtab TO lt_fldtab.

    ls_bseg_template-zfbdt = iv_zfbdt.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      ls_buztab-bukrs = <ls_item>-bukrs.
      ls_buztab-belnr = <ls_item>-belnr.
      ls_buztab-gjahr = <ls_item>-gjahr.
      ls_buztab-buzei = <ls_item>-buzei.
      ls_buztab-bschl = '01'.
      APPEND ls_buztab TO lt_buztab.
    ENDLOOP.

    CALL FUNCTION 'FI_ITEMS_MASS_CHANGE'
      EXPORTING
        s_bseg                = ls_bseg_template
        iv_synchronous_update = abap_true
      IMPORTING
        errtab                = lt_errtab
      TABLES
        it_buztab             = lt_buztab
        it_fldtab             = lt_fldtab
      EXCEPTIONS
        bdc_errors            = 1
        OTHERS                = 2.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_mora_post_error
        EXPORTING iv_msg_text = |FI_ITEMS_MASS_CHANGE fallo (sy-subrc { sy-subrc })|.
    ENDIF.

    " Map del retorno clasico (type group TPIT) al tipo propio de la interfaz
    LOOP AT lt_errtab ASSIGNING FIELD-SYMBOL(<ls_err>).
      APPEND VALUE #( bukrs   = <ls_err>-doc-bukrs
                      belnr   = <ls_err>-doc-belnr
                      gjahr   = <ls_err>-doc-gjahr
                      msgty   = <ls_err>-err-msgtyp
                      msgid   = <ls_err>-err-msgid
                      msgno   = <ls_err>-err-msgnr
                      message = <ls_err>-err-msgv1 ) TO et_errors.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_fi_items_change_zfbdt~change_base_date_direct.
    " Replica fiel del estandar RFVD_CHK_CHANGE_CLEARING adaptada a ZFBDT y masiva.
    " Nombre de tabla y de FM via TVARVC (runtime) -> acceso dinamico.
    DATA: lt_bseg       TYPE tt_bseg,
          lt_bseg_old   TYPE tt_bseg,
          lt_bseg_new   TYPE tt_bseg,
          lt_acdoca     TYPE STANDARD TABLE OF acdoca,
          lt_bwfi       TYPE STANDARD TABLE OF bwfi_aedat,
          ls_bwfi       TYPE bwfi_aedat,
          ls_bseg       TYPE bseg,
          lv_tab_bseg   TYPE tabname,
          lv_tab_acdoca TYPE tabname,
          lv_fm         TYPE funcname.

    CLEAR rt_result.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    " Guarda fatal: en modo real, ZFBDT no puede ser inicial
    IF iv_update = abap_true AND iv_zfbdt IS INITIAL.
      RAISE EXCEPTION TYPE zcx_mora_post_error
        EXPORTING iv_msg_text = 'ZFBDT inicial: no se puede actualizar la fecha base'.
    ENDIF.

    " Nombres de tabla y FM via TVARVC (sin literal estatico -> ATC no resuelve)
    DATA(lo_tvarvc) = NEW zcl_tvarvc( ).
    TRY.
        lo_tvarvc->get_parameter( EXPORTING i_name = c_tvarvc_bseg   IMPORTING e_value = lv_tab_bseg ).
        lo_tvarvc->get_parameter( EXPORTING i_name = c_tvarvc_acdoca IMPORTING e_value = lv_tab_acdoca ).
        lo_tvarvc->get_parameter( EXPORTING i_name = c_tvarvc_fm_bw  IMPORTING e_value = lv_fm ).
      CATCH zcx_tvarvc.
        RAISE EXCEPTION TYPE zcx_mora_post_error
          EXPORTING iv_msg_text = 'Falta parametro TVARVC (ZFI_ZFBDT_TAB_BSEG / _TAB_ACDOCA / _FM_BWDELTA)'.
    ENDTRY.

    " Lectura dinamica de las posiciones (nombre de tabla via variable CHAR)
    SELECT * FROM (lv_tab_bseg)
      FOR ALL ENTRIES IN @it_items
      WHERE bukrs = @it_items-bukrs
        AND belnr = @it_items-belnr
        AND gjahr = @it_items-gjahr
        AND buzei = @it_items-buzei
      INTO TABLE @lt_bseg.

    " ===== FASE A: validacion/simulacion de TODAS las posiciones (sin DML) =====
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<it>).
      DATA(ls_res) = VALUE zif_fi_items_change_zfbdt=>ty_result(
                       bukrs     = <it>-bukrs
                       belnr     = <it>-belnr
                       gjahr     = <it>-gjahr
                       buzei     = <it>-buzei
                       zfbdt_new = iv_zfbdt ).
      READ TABLE lt_bseg INTO ls_bseg
        WITH KEY bukrs = <it>-bukrs
                 belnr = <it>-belnr
                 gjahr = <it>-gjahr
                 buzei = <it>-buzei.
      IF sy-subrc <> 0.
        ls_res-status  = 'ERROR'.
        ls_res-message = 'Posicion no encontrada en la tabla de posiciones'.
        APPEND ls_res TO rt_result.
        CONTINUE.
      ENDIF.
      ls_res-bschl     = ls_bseg-bschl.
      ls_res-koart     = ls_bseg-koart.
      ls_res-shkzg     = ls_bseg-shkzg.
      ls_res-dmbtr     = ls_bseg-dmbtr.
      ls_res-zfbdt_old = ls_bseg-zfbdt.
      ls_res-status    = 'SIMULACION'.
      APPEND ls_bseg TO lt_bseg_old.
      ls_bseg-zfbdt = iv_zfbdt.
      APPEND ls_bseg TO lt_bseg_new.
      MOVE-CORRESPONDING ls_bseg TO ls_bwfi.
      APPEND ls_bwfi TO lt_bwfi.
      APPEND ls_res TO rt_result.
    ENDLOOP.

    " Modo simulacion: retorna sin grabar
    IF iv_update = abap_false.
      RETURN.
    ENDIF.

    " GATE all-or-nothing: si hay algun ERROR, no se graba nada
    IF line_exists( rt_result[ status = 'ERROR' ] ).
      LOOP AT rt_result ASSIGNING FIELD-SYMBOL(<r>) WHERE status = 'SIMULACION'.
        <r>-status = 'NO EJECUTADO'.
      ENDLOOP.
      RETURN.
    ENDIF.

    " ===== FASE B: grabacion set-based, 1 LUW =====
    IF change_documents( it_bseg_old = lt_bseg_old
                         it_bseg_new = lt_bseg_new ) = abap_true.
      ROLLBACK WORK.
      LOOP AT rt_result ASSIGNING FIELD-SYMBOL(<re>) WHERE status = 'SIMULACION'.
        <re>-status  = 'ERROR'.
        <re>-message = 'Error al generar change document'.
      ENDLOOP.
      RETURN.
    ENDIF.

    " UPDATE dinamico de la tabla de posiciones (nombre via variable CHAR)
    UPDATE (lv_tab_bseg) FROM TABLE @lt_bseg_new.

    " ACDOCA - replica fiel (S/4 con Universal Journal siempre activo), tabla dinamica
    SELECT * FROM (lv_tab_acdoca)
      FOR ALL ENTRIES IN @lt_bseg_new
      WHERE rbukrs = @lt_bseg_new-bukrs
        AND belnr  = @lt_bseg_new-belnr
        AND gjahr  = @lt_bseg_new-gjahr
        AND buzei  = @lt_bseg_new-buzei
      INTO TABLE @lt_acdoca.
    IF lt_acdoca IS NOT INITIAL.
      UPDATE (lv_tab_acdoca) FROM TABLE @lt_acdoca.
    ENDIF.

    " Delta BW - nombre del FM via TVARVC (call dinamico)
    CALL FUNCTION lv_fm
      EXPORTING i_save_directly = 'X'
      TABLES    i_t_bkpf        = lt_bwfi.

    COMMIT WORK.

    LOOP AT rt_result ASSIGNING FIELD-SYMBOL(<ok>) WHERE status = 'SIMULACION'.
      <ok>-status = 'OK'.
    ENDLOOP.
  ENDMETHOD.


  METHOD change_documents.
    " Genera change documents (objeto BELEG) en UNA sola pasada: acumula las
    " lineas por documento y, al cambiar de documento (AT END OF), llama a la
    " API estandar de change document. Sin LOOP anidado.
    DATA: lv_objectid TYPE cdhdr-objectid,
          lt_old_fb   TYPE STANDARD TABLE OF fbseg,
          lt_new_fb   TYPE STANDARD TABLE OF fbseg,
          ls_old      TYPE bseg.
    DATA lt_new TYPE tt_bseg.
    DATA lt_old TYPE SORTED TABLE OF bseg WITH UNIQUE KEY bukrs belnr gjahr buzei.

    lt_new = it_bseg_new.
    lt_old = it_bseg_old.
    SORT lt_new BY bukrs belnr gjahr buzei.

    LOOP AT lt_new INTO DATA(ls_n).
      APPEND CORRESPONDING #( ls_n ) TO lt_new_fb.
      READ TABLE lt_old INTO ls_old
        WITH KEY bukrs = ls_n-bukrs
                 belnr = ls_n-belnr
                 gjahr = ls_n-gjahr
                 buzei = ls_n-buzei.
      IF sy-subrc = 0.
        APPEND CORRESPONDING #( ls_old ) TO lt_old_fb.
      ENDIF.

      AT END OF gjahr.
        lv_objectid = ls_n+0(21).

        CALL FUNCTION 'CHANGEDOCUMENT_OPEN'
          EXPORTING
            objectclass      = 'BELEG'
            objectid         = lv_objectid
          EXCEPTIONS
            sequence_invalid = 1
            OTHERS           = 2.
        IF sy-subrc <> 0.
          rv_error = abap_true.
          RETURN.
        ENDIF.

        CALL FUNCTION 'CHANGEDOCUMENT_MULTIPLE_CASE'
          EXPORTING
            tablename              = 'BSEG'
            reftablename           = 'XF05L'
            change_indicator       = 'U'
            docu_delete            = ' '
          TABLES
            table_old              = lt_old_fb
            table_new              = lt_new_fb
          EXCEPTIONS
            nametab_error          = 1
            open_missing           = 2
            position_insert_failed = 3
            OTHERS                 = 4.
        IF sy-subrc <> 0.
          rv_error = abap_true.
          RETURN.
        ENDIF.

        CALL FUNCTION 'CHANGEDOCUMENT_CLOSE'
          EXPORTING
            objectclass    = 'BELEG'
            objectid       = lv_objectid
            date_of_change = sy-datum
            time_of_change = sy-uzeit
            tcode          = sy-tcode
            username       = sy-uname
          EXCEPTIONS
            OTHERS         = 1.
        IF sy-subrc <> 0.
          rv_error = abap_true.
          RETURN.
        ENDIF.

        CLEAR: lt_old_fb, lt_new_fb.
      ENDAT.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
