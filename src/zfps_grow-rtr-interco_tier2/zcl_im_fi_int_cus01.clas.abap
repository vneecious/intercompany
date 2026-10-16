CLASS zcl_im_fi_int_cus01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_fi_int_cus01.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_bseg_key,
        bukrs TYPE bukrs,
        belnr TYPE belnr_d,
        gjahr TYPE gjahr,
        buzei TYPE buzei,
        vbund TYPE vbund,
        zinkz TYPE char1,
        kostl TYPE kostl,
        prctr TYPE prctr,
        matnr TYPE matnr,
      END OF ty_bseg_key,
      tt_bseg_key TYPE HASHED TABLE OF ty_bseg_key
                  WITH UNIQUE KEY bukrs belnr gjahr buzei,

      BEGIN OF ty_glacct,
        provider_company_code  TYPE zint_a_md_glacct-provider_company_code,
        recipient_company_code TYPE zint_a_md_glacct-recipient_company_code,
        product                TYPE zint_a_md_glacct-product,
        gl_account1            TYPE zint_a_md_glacct-gl_account1,
        gl_account2            TYPE zint_a_md_glacct-gl_account2,
        doc_type               TYPE zint_a_md_glacct-doc_type,
      END OF ty_glacct,
      tt_glacct TYPE HASHED TABLE OF ty_glacct
                WITH UNIQUE KEY provider_company_code recipient_company_code product.

    " === Migracion BAPI_ACC_DOCUMENT_POST -> EML I_JournalEntryTP (SDFPSINIC-23382) ===
    " Buffer de documentos EML. Se acumula en INT_POST y se ejecuta en END_OF_PROGRAMM.
    DATA mt_je_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.

    CONSTANTS:
      c_doctype_ap   TYPE blart      VALUE 'IR',
      c_doctype_recl TYPE blart      VALUE 'CH',
      c_bus_act      TYPE c LENGTH 4 VALUE 'RFBU',
      c_ledger_recl  TYPE c LENGTH 4 VALUE '0LL1',
      c_gl_clearing  TYPE hkont      VALUE '0000469001',
      c_ccyrole_doc  TYPE c LENGTH 2 VALUE '00'.

    CLASS-METHODS:
      get_bseg_data
        IMPORTING
          it_items       TYPE fint_tt_intit_extf
        RETURNING
          VALUE(rt_bseg) TYPE tt_bseg_key,

      get_quarter_close_date
        IMPORTING
          iv_date_ref    TYPE datum
        RETURNING
          VALUE(rv_date) TYPE datum,

      get_exchange_rate
        IMPORTING
          iv_fcurr       TYPE waers
          iv_date        TYPE datum
        RETURNING
          VALUE(rv_rate) TYPE tcurr-ukurs,

      convert_to_usd
        IMPORTING
          iv_amount      TYPE wrbtr
          iv_waers       TYPE waers
          iv_date        TYPE datum
        RETURNING
          VALUE(rv_usd)  TYPE wrbtr,

      append_log_warn
        IMPORTING
          iv_msgid       TYPE symsgid
          iv_msgno       TYPE symsgno
          iv_msgv1       TYPE clike OPTIONAL
          iv_msgv2       TYPE clike OPTIONAL
        CHANGING
          ct_log         TYPE fint_tt_log.

    METHODS:
      build_ap_document_eml
        IMPORTING
          is_t001   TYPE t001
          is_ipf    TYPE intipf
          it_accit  TYPE fint_tt_accit
          it_bseg   TYPE tt_bseg_key
          it_glacct TYPE tt_glacct,

      build_reclass_document_eml
        IMPORTING
          is_t001   TYPE t001
          is_ipf    TYPE intipf
          it_accit  TYPE fint_tt_accit
          it_bseg   TYPE tt_bseg_key
          it_glacct TYPE tt_glacct.

    METHODS:
      post_ap_document
        IMPORTING
          is_t001        TYPE t001
          is_ipf         TYPE intipf
          it_accit       TYPE fint_tt_accit
          it_bseg        TYPE tt_bseg_key
          it_glacct      TYPE tt_glacct
        RAISING
          zcx_mora_post_error,

      post_reclassification
        IMPORTING
          is_t001        TYPE t001
          is_ipf         TYPE intipf
          it_accit       TYPE fint_tt_accit
          it_bseg        TYPE tt_bseg_key
          it_glacct      TYPE tt_glacct
        RAISING
          zcx_mora_post_error.

ENDCLASS.



CLASS zcl_im_fi_int_cus01 IMPLEMENTATION.


  METHOD append_log_warn.
    DATA ls_log_line LIKE LINE OF ct_log.
    ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_ty>).
    ASSIGN COMPONENT 'MSGID' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_id>).
    ASSIGN COMPONENT 'MSGNO' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_no>).
    ASSIGN COMPONENT 'MSGV1' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_v1>).
    ASSIGN COMPONENT 'MSGV2' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_v2>).
    IF <f_ty> IS ASSIGNED. <f_ty> = 'W'.      ENDIF.
    IF <f_id> IS ASSIGNED. <f_id> = iv_msgid. ENDIF.
    IF <f_no> IS ASSIGNED. <f_no> = iv_msgno. ENDIF.
    IF <f_v1> IS ASSIGNED AND iv_msgv1 IS SUPPLIED. <f_v1> = iv_msgv1. ENDIF.
    IF <f_v2> IS ASSIGNED AND iv_msgv2 IS SUPPLIED. <f_v2> = iv_msgv2. ENDIF.
    APPEND ls_log_line TO ct_log.
  ENDMETHOD.


  METHOD convert_to_usd.
    IF iv_waers = 'USD'.
      rv_usd = iv_amount.
      RETURN.
    ENDIF.
    DATA(lv_rate) = get_exchange_rate( iv_fcurr = iv_waers iv_date = iv_date ).
    IF lv_rate <> 0.
      rv_usd = iv_amount / lv_rate.
    ENDIF.
  ENDMETHOD.


  METHOD get_bseg_data.
    " ZINKZ no esta expuesto por defecto en I_OperationalAcctgDocItem (SAP lo comenta).
    " Se expone via la extension CDS ZZEX_OPACCTG_ZINKZ
    " (extend view I_OperationalAcctgDocItem { P_BSEG_COM.zinkz as InterestBlock }),
    " por lo que esta clase lee item + ZINKZ con un unico SELECT a la vista LIBERADA,
    " sin acceso directo a BSEG. Excepcion Clean Core acotada a la extension. Nota SAP 2431747.
    " Decision C1 (eliminar lectura ZINKZ y confiar en estandar FINT) PENDIENTE de
    " validacion funcional en TS4 -> hasta entonces se mantiene la lectura.
    CHECK it_items IS NOT INITIAL.

    SELECT CompanyCode            AS bukrs,
           AccountingDocument     AS belnr,
           FiscalYear             AS gjahr,
           AccountingDocumentItem AS buzei,
           PartnerCompany         AS vbund,
           CostCenter             AS kostl,
           ProfitCenter           AS prctr,
           Material               AS matnr,
           InterestBlock          AS zinkz
      FROM i_operationalacctgdocitem
      FOR ALL ENTRIES IN @it_items
      WHERE CompanyCode            = @it_items-bukrs
        AND AccountingDocument     = @it_items-belnr
        AND FiscalYear             = @it_items-gjahr
        AND AccountingDocumentItem = @it_items-buzei
      INTO CORRESPONDING FIELDS OF TABLE @rt_bseg.

  ENDMETHOD.


  METHOD get_exchange_rate.
    DATA lv_max_date TYPE i_exchangeraterawdata-ValidityStartDate.

    SELECT MAX( ValidityStartDate )
      FROM I_ExchangeRateRawData
      WHERE ExchangeRateType  = 'B'
        AND SourceCurrency    = @iv_fcurr
        AND TargetCurrency    = 'USD'
        AND ValidityStartDate <= @iv_date
      INTO @lv_max_date.

    IF sy-subrc = 0 AND lv_max_date IS NOT INITIAL.
      SELECT SINGLE ExchangeRate
        FROM I_ExchangeRateRawData
        WHERE ExchangeRateType  = 'B'
          AND SourceCurrency    = @iv_fcurr
          AND TargetCurrency    = 'USD'
          AND ValidityStartDate = @lv_max_date
        INTO @rv_rate.
    ENDIF.

    IF rv_rate IS INITIAL.
      rv_rate = 1.
    ENDIF.
  ENDMETHOD.


  METHOD get_quarter_close_date.
    DATA(lv_month) = iv_date_ref+4(2).
    CASE lv_month.
      WHEN '01' OR '02' OR '03'. rv_date = |{ iv_date_ref(4) }0331|.
      WHEN '04' OR '05' OR '06'. rv_date = |{ iv_date_ref(4) }0630|.
      WHEN '07' OR '08' OR '09'. rv_date = |{ iv_date_ref(4) }0930|.
      WHEN OTHERS.               rv_date = |{ iv_date_ref(4) }1231|.
    ENDCASE.
  ENDMETHOD.


  METHOD build_ap_document_eml.
    " Doc2 - Cuentas por Pagar (AP). Clase doc IR.
    "   D- Cuenta gasto 693xxx6 (GL)  |  H- Proveedor prestador MLA (_apitems-supplier)
    "   TC tipo B cierre quarter via _currencyamount-exchangerate.
    DATA(lv_close) = get_quarter_close_date( is_ipf-netdt ).
    DATA(lv_kursf) = get_exchange_rate( iv_fcurr = is_ipf-int_curr
                                        iv_date  = lv_close ).
    DATA(lv_htxt)  = |INT MORA IC Q{ lv_close+4(2) } { lv_close(4) }|.

    DATA ls_je TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post.
    ls_je-%cid                                = |MORA{ lines( mt_je_post ) + 1 }|.
    ls_je-%param-companycode                  = is_t001-bukrs.
    ls_je-%param-accountingdocumenttype       = c_doctype_ap.
    ls_je-%param-businesstransactiontype      = c_bus_act.
    ls_je-%param-accountingdocumentheadertext = lv_htxt.
    ls_je-%param-documentdate                 = is_ipf-netdt.
    ls_je-%param-postingdate                  = is_ipf-netdt.
    ls_je-%param-createdbyuser                = sy-uname.
    ls_je-%param-documentreferenceid          = is_ipf-int_belnr.

    DATA lv_item  TYPE n LENGTH 6 VALUE 1.
    DATA lv_matnr TYPE productnumber.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_accit>).

      READ TABLE it_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = is_t001-bukrs
                       belnr = <ls_accit>-belnr
                       gjahr = <ls_accit>-gjahr
                       buzei = <ls_accit>-buzei.
      IF <ls_bseg> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_matnr = <ls_bseg>-matnr.
      READ TABLE it_glacct ASSIGNING FIELD-SYMBOL(<ls_acc>)
        WITH TABLE KEY
          provider_company_code  = is_t001-bukrs
          recipient_company_code = CONV #( <ls_bseg>-vbund )
          product                = lv_matnr.
      IF <ls_acc> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      " GL: Debe - cuenta gasto 693xxx6
      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = <ls_acc>-gl_account1
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

      " AP: Haber - proveedor prestador (VENDOR_NO -> supplier)
      APPEND VALUE #(
        glaccountlineitem = lv_item
        supplier          = CONV #( <ls_bseg>-vbund )
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount * -1
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_apitems.
      lv_item += 1.

    ENDLOOP.

    IF ls_je-%param-_glitems IS INITIAL.
      RETURN.
    ENDIF.
    APPEND ls_je TO mt_je_post.

  ENDMETHOD.


  METHOD build_reclass_document_eml.
    " Doc3 - Reclasificacion (CH) libro 0L->L1 (ledger group 0LL1).
    "   D- Cuenta ingreso 692xxx6  |  H- Cuenta transitoria 469001
    DATA(lv_close) = get_quarter_close_date( is_ipf-netdt ).
    DATA(lv_kursf) = get_exchange_rate( iv_fcurr = is_ipf-int_curr
                                        iv_date  = lv_close ).
    DATA(lv_htxt)  = |RECLAS INT MORA IC Q{ lv_close+4(2) } { lv_close(4) }|.

    DATA ls_je TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post.
    ls_je-%cid                                = |MORA{ lines( mt_je_post ) + 1 }|.
    ls_je-%param-companycode                  = is_t001-bukrs.
    ls_je-%param-accountingdocumenttype       = c_doctype_recl.
    ls_je-%param-businesstransactiontype      = c_bus_act.
    ls_je-%param-ledgergroup                  = c_ledger_recl.
    ls_je-%param-accountingdocumentheadertext = lv_htxt.
    ls_je-%param-documentdate                 = is_ipf-netdt.
    ls_je-%param-postingdate                  = is_ipf-netdt.
    ls_je-%param-createdbyuser                = sy-uname.
    ls_je-%param-documentreferenceid          = is_ipf-int_belnr.

    DATA lv_item  TYPE n LENGTH 6 VALUE 1.
    DATA lv_matnr TYPE productnumber.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_accit>).

      READ TABLE it_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = is_t001-bukrs
                       belnr = <ls_accit>-belnr
                       gjahr = <ls_accit>-gjahr
                       buzei = <ls_accit>-buzei.
      IF <ls_bseg> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_matnr = <ls_bseg>-matnr.
      READ TABLE it_glacct ASSIGNING FIELD-SYMBOL(<ls_acc>)
        WITH TABLE KEY
          provider_company_code  = is_t001-bukrs
          recipient_company_code = CONV #( <ls_bseg>-vbund )
          product                = lv_matnr.
      IF <ls_acc> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      " Debe - cuenta ingreso 692xxx6
      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = <ls_acc>-gl_account2
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

      " Haber - cuenta transitoria 469001
      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = c_gl_clearing
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount * -1
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

    ENDLOOP.

    IF ls_je-%param-_glitems IS INITIAL.
      RETURN.
    ENDIF.
    APPEND ls_je TO mt_je_post.

  ENDMETHOD.


  METHOD post_ap_document.
*   ==========================================================================
*   BAPI COMENTADA - migrada a EML (build_ap_document_eml). SDFPSINIC-23382.
*   Conservada para rollback / validacion en TS4; eliminar tras validacion OK.
*   Codigo original preservado en backup_codigo_20260602/.
*   ==========================================================================
    RETURN.
  ENDMETHOD.


  METHOD post_reclassification.
*   ==========================================================================
*   BAPI COMENTADA - migrada a EML (build_reclass_document_eml). SDFPSINIC-23382.
*   Conservada para rollback / validacion en TS4; eliminar tras validacion OK.
*   Codigo original preservado en backup_codigo_20260602/.
*   ==========================================================================
    RETURN.
  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~end_of_programm.

    DATA lt_log_entries TYPE STANDARD TABLE OF zfint_post_log.
    DATA lv_uuid        TYPE c LENGTH 32.

    " (R1) Run sin documentos Mora -> NO tocar la LUW del documento estandar del FINT
    IF mt_je_post IS INITIAL.
      RETURN.
    ENDIF.

    " Hubo error previo registrado en ct_log durante el procesamiento?
    DATA(lv_prev_error) = abap_false.
    LOOP AT ct_log ASSIGNING FIELD-SYMBOL(<ls_chk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE <ls_chk> TO FIELD-SYMBOL(<lv_ty0>).
      IF <lv_ty0> IS ASSIGNED AND ( <lv_ty0> = 'E' OR <lv_ty0> = 'A' ).
        lv_prev_error = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    " (R2) Blindaje tecnico: cualquier dump en el posting Mora -> ROLLBACK + log, sin abortar el FINT
    TRY.
        " Error previo en el calculo Mora -> revertir Doc2+Doc3 (y LUW pendiente)
        IF lv_prev_error = abap_true.
          ROLLBACK ENTITIES.

          LOOP AT ct_log ASSIGNING FIELD-SYMBOL(<ls_err>).
            ASSIGN COMPONENT 'MSGTY' OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_ty>).
            IF <lv_ty> IS NOT ASSIGNED. CONTINUE. ENDIF.
            IF <lv_ty> <> 'E' AND <lv_ty> <> 'A'. CONTINUE. ENDIF.

            ASSIGN COMPONENT 'MSGID'   OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_id>).
            ASSIGN COMPONENT 'MSGNO'   OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_no>).
            ASSIGN COMPONENT 'MESSAGE' OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_msg>).

            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.

            DATA ls_entry TYPE zfint_post_log.
            CLEAR ls_entry.
            ls_entry-log_id     = lv_uuid.
            ls_entry-run_status = 'ER'.
            ls_entry-doc_status = 'RB'.
            ls_entry-severity   = 'E'.
            IF <lv_id>  IS ASSIGNED. ls_entry-msgid    = <lv_id>.  ENDIF.
            IF <lv_no>  IS ASSIGNED. ls_entry-msgno    = <lv_no>.  ENDIF.
            IF <lv_msg> IS ASSIGNED. ls_entry-msg_text = <lv_msg>. ENDIF.
            ls_entry-erdat = sy-datum.
            ls_entry-erzet = sy-uzeit.
            ls_entry-ernam = sy-uname.
            APPEND ls_entry TO lt_log_entries.
          ENDLOOP.

          IF lt_log_entries IS NOT INITIAL.
            MODIFY zfint_post_log FROM TABLE lt_log_entries.
          ENDIF.
          RETURN.
        ENDIF.

        " === Ejecutar documentos EML (Doc2 AP + Doc3 reclass) ===
        MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
          ENTITY journalentry
          EXECUTE post FROM mt_je_post
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported)
          MAPPED   DATA(ls_mapped).

        IF ls_failed-journalentry IS NOT INITIAL.
          ROLLBACK ENTITIES.

          LOOP AT ls_reported-journalentry ASSIGNING FIELD-SYMBOL(<ls_rep>).
            IF <ls_rep>-%msg IS NOT BOUND. CONTINUE. ENDIF.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            DATA ls_err_eml TYPE zfint_post_log.
            CLEAR ls_err_eml.
            ls_err_eml-log_id     = lv_uuid.
            ls_err_eml-run_status = 'ER'.
            ls_err_eml-doc_status = 'RB'.
            ls_err_eml-severity   = 'E'.
            ls_err_eml-msg_text   = <ls_rep>-%msg->if_message~get_text( ).
            ls_err_eml-erdat      = sy-datum.
            ls_err_eml-erzet      = sy-uzeit.
            ls_err_eml-ernam      = sy-uname.
            APPEND ls_err_eml TO lt_log_entries.
          ENDLOOP.

          IF lt_log_entries IS NOT INITIAL.
            MODIFY zfint_post_log FROM TABLE lt_log_entries.
          ENDIF.
          RETURN.
        ENDIF.

        COMMIT ENTITIES BEGIN
          RESPONSE OF i_journalentrytp
          FAILED   DATA(ls_save_failed)
          REPORTED DATA(ls_save_reported).

        IF ls_save_failed-journalentry IS NOT INITIAL.
          ROLLBACK ENTITIES.
          TRY.
              lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
            CATCH cx_uuid_error.
              lv_uuid = sy-datum && sy-uzeit.
          ENDTRY.
          DATA ls_cerr TYPE zfint_post_log.
          CLEAR ls_cerr.
          ls_cerr-log_id     = lv_uuid.
          ls_cerr-run_status = 'ER'.
          ls_cerr-doc_status = 'RB'.
          ls_cerr-severity   = 'E'.
          ls_cerr-msg_text   = 'Error en COMMIT ENTITIES del posting EML'.
          ls_cerr-erdat      = sy-datum.
          ls_cerr-erzet      = sy-uzeit.
          ls_cerr-ernam      = sy-uname.
          APPEND ls_cerr TO lt_log_entries.
        ELSE.
          LOOP AT ls_mapped-journalentry ASSIGNING FIELD-SYMBOL(<ls_map>).
            CONVERT KEY OF i_journalentrytp FROM <ls_map>-%pid TO DATA(ls_final_key).
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            DATA ls_ok TYPE zfint_post_log.
            CLEAR ls_ok.
            ls_ok-log_id     = lv_uuid.
            ls_ok-run_status = 'SC'.
            ls_ok-doc_status = 'AC'.
            ls_ok-severity   = 'S'.
            ls_ok-bukrs      = ls_final_key-companycode.
            ls_ok-msg_text   = |Doc { ls_final_key-accountingdocument } contabilizado correctamente|.
            ls_ok-erdat      = sy-datum.
            ls_ok-erzet      = sy-uzeit.
            ls_ok-ernam      = sy-uname.
            APPEND ls_ok TO lt_log_entries.
          ENDLOOP.
        ENDIF.
        COMMIT ENTITIES END.

      CATCH cx_root INTO DATA(lx_tech).
        ROLLBACK ENTITIES.
        TRY.
            lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
          CATCH cx_uuid_error.
            lv_uuid = sy-datum && sy-uzeit.
        ENDTRY.
        DATA ls_terr TYPE zfint_post_log.
        CLEAR ls_terr.
        ls_terr-log_id     = lv_uuid.
        ls_terr-run_status = 'ER'.
        ls_terr-doc_status = 'RB'.
        ls_terr-severity   = 'E'.
        ls_terr-msg_text   = |Error tecnico (dump) en posting Mora: { lx_tech->get_text( ) }|.
        ls_terr-erdat      = sy-datum.
        ls_terr-erzet      = sy-uzeit.
        ls_terr-ernam      = sy-uname.
        APPEND ls_terr TO lt_log_entries.
    ENDTRY.

    IF lt_log_entries IS NOT INITIAL.
      MODIFY zfint_post_log FROM TABLE lt_log_entries.
    ENDIF.

  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~get_int_sign.           ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_add_items.

    DATA(lt_bseg) = get_bseg_data( ct_items ).

    DATA lt_brasil TYPE RANGE OF vbund.
    lt_brasil = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'MLB' )
      ( sign = 'I' option = 'EQ' low = 'MLE' )
      ( sign = 'I' option = 'EQ' low = 'MLM' ) ).

    DATA lt_arg TYPE RANGE OF vbund.
    lt_arg = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'MSP' )
      ( sign = 'I' option = 'EQ' low = 'MLO' )
      ( sign = 'I' option = 'EQ' low = 'MPY' )
      ( sign = 'I' option = 'EQ' low = 'MPA' ) ).

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      DATA(lv_exclude) = abap_false.

      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = <ls_item>-bukrs
                       belnr = <ls_item>-belnr
                       gjahr = <ls_item>-gjahr
                       buzei = <ls_item>-buzei.

      IF <ls_item>-blart = 'AJ' OR <ls_item>-blart = 'AI'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND <ls_bseg>-zinkz = '01'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND <ls_bseg>-vbund IN lt_arg.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND
         ( <ls_item>-zuonr CS 'BACKOFFICE' OR
           <ls_item>-zuonr CS 'NEG MGT' ) AND
         <ls_bseg>-vbund IN lt_brasil.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_item>-blart = 'IO'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_item>-umskz = 'F'.
        lv_exclude = abap_true.
      ENDIF.

      IF lv_exclude = abap_true.
        DELETE ct_items.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_change_items.       ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_formula.            ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_group.

    DATA(lt_bseg) = get_bseg_data( it_items ).

    LOOP AT ct_sum ASSIGNING FIELD-SYMBOL(<ls_sum>).

      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = <ls_sum>-bukrs
                       belnr = <ls_sum>-belnr
                       gjahr = <ls_sum>-gjahr
                       buzei = <ls_sum>-buzei.

      IF <ls_bseg> IS ASSIGNED.
        <ls_sum>-array = |{ <ls_sum>-bukrs }{ <ls_bseg>-vbund }{ <ls_bseg>-matnr }{ <ls_sum>-int_curr }|.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_list_01.            ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_list_02.            ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_list_03.            ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_modify_items.

    DATA lv_umbral_usd TYPE wrbtr.
    DATA lv_moneda_usd TYPE waers.

    SELECT SINGLE Low FROM ZI_TVARVC
      WHERE Name = 'ZFI_INT_MONEDA_USD' AND Type = 'P'
      INTO @lv_moneda_usd.
    IF sy-subrc <> 0.
      lv_moneda_usd = 'USD'.
    ENDIF.

    SELECT SINGLE Low FROM ZI_TVARVC
      WHERE Name = 'ZFI_INT_UMBRAL_USD' AND Type = 'P'
      INTO @DATA(lv_umbral_str).
    IF sy-subrc = 0.
      lv_umbral_usd = lv_umbral_str.
    ELSE.
      lv_umbral_usd = '5000.00'.
    ENDIF.

    DATA lv_ref_date TYPE datum.
    READ TABLE ct_items INDEX 1 INTO DATA(ls_first_item).
    IF sy-subrc = 0.
      lv_ref_date = ls_first_item-bldat.
    ELSE.
      lv_ref_date = sy-datum.
    ENDIF.
    DATA(lv_rate_usd) = get_exchange_rate(
      iv_fcurr = lv_moneda_usd
      iv_date  = lv_ref_date ).

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      DATA lv_int_usd TYPE wrbtr.

      IF <ls_item>-int_curr = lv_moneda_usd.
        lv_int_usd = <ls_item>-int_amount.
      ELSE.
        IF lv_rate_usd <> 0.
          lv_int_usd = <ls_item>-int_amount / lv_rate_usd.
        ELSE.
          lv_int_usd = <ls_item>-int_amount.
        ENDIF.
      ENDIF.

      IF lv_int_usd < lv_umbral_usd.
        DELETE ct_items.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_post.

    DATA(lv_close_date) = get_quarter_close_date( cs_ipf-netdt ).
    DATA(lt_bseg)       = get_bseg_data( ct_items ).

    DATA(lv_kursf) = get_exchange_rate(
      iv_fcurr = cs_ipf-int_curr
      iv_date  = lv_close_date ).

    DATA lt_glacct TYPE tt_glacct.
    DATA lv_matnr_conv TYPE productnumber.
    SELECT provider_company_code, recipient_company_code,
           product, gl_account1, gl_account2, doc_type
      FROM zint_a_md_glacct
      WHERE provider_company_code = @is_t001-bukrs
        AND tariff_type           = '04'
        AND valid_from           <= @sy-datum
        AND valid_to             >= @sy-datum
        AND is_deleted            = @abap_false
      INTO CORRESPONDING FIELDS OF TABLE @lt_glacct.

    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_accit>).

      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = is_t001-bukrs
                       belnr = <ls_accit>-docln
                       gjahr = cs_ipf-int_gjahr
                       buzei = <ls_accit>-posnr.

      IF <ls_bseg> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_matnr_conv = <ls_bseg>-matnr.
      READ TABLE lt_glacct ASSIGNING FIELD-SYMBOL(<ls_accounts>)
        WITH TABLE KEY
          provider_company_code  = is_t001-bukrs
          recipient_company_code = CONV #( <ls_bseg>-vbund )
          product                = lv_matnr_conv.

      IF sy-subrc <> 0.
        append_log_warn(
          EXPORTING
            iv_msgid = 'ZFI_INT'
            iv_msgno = '001'
            iv_msgv1 = is_t001-bukrs
            iv_msgv2 = <ls_bseg>-vbund
          CHANGING
            ct_log   = ct_log ).
        CONTINUE.
      ENDIF.

      CASE <ls_accit>-shkzg.
        WHEN 'S'. <ls_accit>-hkont = <ls_accounts>-gl_account1.
        WHEN 'H'. <ls_accit>-hkont = <ls_accounts>-gl_account2.
      ENDCASE.

      cs_ipf-a_form    = <ls_accounts>-doc_type.
      <ls_accit>-kostl = <ls_bseg>-kostl.
      <ls_accit>-prctr = <ls_bseg>-prctr.

    ENDLOOP.

    " T54/T55 - Acumular Doc2 (AP IR) y Doc3 (CH 0LL1) en el buffer EML.
    " La ejecucion (EXECUTE post) + COMMIT/ROLLBACK ENTITIES la controla end_of_programm.
    build_ap_document_eml(
      is_t001   = is_t001
      is_ipf    = cs_ipf
      it_accit  = ct_accit
      it_bseg   = lt_bseg
      it_glacct = lt_glacct ).

    build_reclass_document_eml(
      is_t001   = is_t001
      is_ipf    = cs_ipf
      it_accit  = ct_accit
      it_bseg   = lt_bseg
      it_glacct = lt_glacct ).

*   --- BAPI comentada (migrada a EML; conservada para validacion TS4) ---
*    TRY.
*        post_ap_document(
*          is_t001   = is_t001
*          is_ipf    = cs_ipf
*          it_accit  = ct_accit
*          it_bseg   = lt_bseg
*          it_glacct = lt_glacct ).
*
*        post_reclassification(
*          is_t001   = is_t001
*          is_ipf    = cs_ipf
*          it_accit  = ct_accit
*          it_bseg   = lt_bseg
*          it_glacct = lt_glacct ).
*
*      CATCH zcx_mora_post_error INTO DATA(lx_post).
*        DATA ls_log_err LIKE LINE OF ct_log.
*        ASSIGN COMPONENT 'MSGTY'   OF STRUCTURE ls_log_err TO FIELD-SYMBOL(<f_ty>).
*        ASSIGN COMPONENT 'MESSAGE' OF STRUCTURE ls_log_err TO FIELD-SYMBOL(<f_msg>).
*        IF <f_ty>  IS ASSIGNED. <f_ty>  = 'E'. ENDIF.
*        IF <f_msg> IS ASSIGNED. <f_msg> = lx_post->get_error_text( ). ENDIF.
*        APPEND ls_log_err TO ct_log.
*    ENDTRY.

  ENDMETHOD.


  METHOD if_ex_fi_int_cus01~int_print_options.      ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_print_results.      ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_print_spool_closed. ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_reverse.            ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_sel_mod.            ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_show_buttons.       ENDMETHOD.
  METHOD if_ex_fi_int_cus01~int_write_items.        ENDMETHOD.
  METHOD if_ex_fi_int_cus01~sort_master_data.       ENDMETHOD.

ENDCLASS.
