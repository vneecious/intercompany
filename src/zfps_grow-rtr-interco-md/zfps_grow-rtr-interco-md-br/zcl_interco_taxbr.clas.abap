CLASS zcl_interco_taxbr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF co_doctype,
                 sales              TYPE zint_txbr_doctype VALUE 'AR',
                 purchase           TYPE zint_txbr_doctype VALUE 'AP',
                 sales_taxbr_reclas TYPE zint_txbr_doctype VALUE 'TR',
                 purch_taxbr_reclas TYPE zint_txbr_doctype VALUE 'TP',
               END OF co_doctype.

    CONSTANTS: BEGIN OF co_taxtype,
                 iss    TYPE zint_txbr_taxtype VALUE 'ISS',
                 pis    TYPE zint_txbr_taxtype VALUE 'PIS',
                 cofins TYPE zint_txbr_taxtype VALUE 'COFINS',
                 cide   TYPE zint_txbr_taxtype VALUE 'CIDE',
                 cpbr   TYPE zint_txbr_taxtype VALUE 'CPBR',
               END OF co_taxtype.

    TYPES: BEGIN OF ty_brtax,
             taxtype       TYPE zi_intercotaxbritem-taxtype,
             taxrate       TYPE zi_intercotaxbritem-taxrate,
             glaccount     TYPE zi_intercotaxbritem-glaccount1,
             glaccount_ind TYPE int1,
           END OF ty_brtax.

    TYPES: BEGIN OF ty_brtax_full,
             providercompanycode  TYPE zi_intercotaxbr-providercompanycode,
             recipientcompanycode TYPE  zi_intercotaxbr-recipientcompanycode,
             product              TYPE zi_intercotaxbr-product,
             department           TYPE zi_intercotaxbr-department.
             INCLUDE TYPE ty_brtax.
    TYPES:   classif              TYPE zi_intercotaxbritem-classif.
    TYPES: END OF ty_brtax_full.

    TYPES: BEGIN OF ty_totals,
             currency_role TYPE curtp,
             currency      TYPE waers,
             amount        TYPE wrbtr,
           END OF ty_totals.

    DATA dummy_journalentries TYPE TABLE FOR ACTION IMPORT i_journalentrytp\\journalentry~post.
    DATA dummy_journalentry LIKE LINE OF dummy_journalentries.

    DATA dummy_glitem LIKE LINE OF dummy_journalentry-%param-_glitems.
    TYPES:
        ty_shadow_glitem LIKE dummy_glitem.

    TYPES:
      BEGIN OF ty_custom_glitems.
        INCLUDE TYPE ty_shadow_glitem.
    TYPES: taxtype TYPE zi_intercotaxbritem-taxtype.
    TYPES: glaccount_origin TYPE i_journalentryitem-glaccount.
    TYPES: END OF ty_custom_glitems.
    TYPES tt_custom_glitems TYPE TABLE OF ty_custom_glitems.

    TYPES: tt_brtaxes TYPE TABLE OF ty_brtax WITH KEY taxtype.
    TYPES: tt_brtaxes_full TYPE TABLE OF ty_brtax_full WITH KEY providercompanycode recipientcompanycode product taxtype.
    TYPES: tt_totals TYPE TABLE OF ty_totals WITH KEY currency_role currency.
    DATA data TYPE tt_brtaxes_full READ-ONLY.

    METHODS constructor
      IMPORTING
                i_doctype              TYPE zi_intercotaxbr-documenttype DEFAULT co_doctype-purchase
                i_taxtype              TYPE zi_intercotaxbritem-taxtype OPTIONAL
                i_valid_at             TYPE datum DEFAULT sy-datum
                i_product              TYPE matnr
                i_department           TYPE zint_depto
                i_providercompanycode  TYPE bukrs
                i_recipientcompanycode TYPE bukrs
                i_skip_glaccount2      TYPE abap_bool DEFAULT space
                i_contingency          TYPE abap_bool OPTIONAL
      RAISING   zcx_interco_taxbr.



    METHODS calculate_taxes_net
      IMPORTING
        it_glitems        LIKE dummy_journalentry-%param-_glitems
      EXPORTING
        et_glitems        LIKE dummy_journalentry-%param-_glitems
        et_glitems_custom TYPE tt_custom_glitems
        ev_total          TYPE i_journalentryitem-amountintransactioncurrency
        et_totals         TYPE tt_totals.


    METHODS replace_accounts
      IMPORTING
        it_glitems TYPE tt_custom_glitems
      EXPORTING
        et_glitems TYPE tt_custom_glitems.

* Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: declaraciones agrupamiento de posiciones _glitems
    TYPES tt_glitems_agg TYPE STANDARD TABLE OF ty_shadow_glitem WITH EMPTY KEY.

    CONSTANTS mc_max_glitems_threshold TYPE i VALUE 950.

    CLASS-METHODS use_new_aggregation
      RETURNING VALUE(rv_use_new) TYPE abap_bool.

    CLASS-METHODS aggregate_glitems
      CHANGING ct_glitems TYPE tt_glitems_agg.
* Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: declaraciones agrupamiento de posiciones _glitems

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA: instance TYPE REF TO zcl_interco_taxbr.

    DATA: is_interdivisional TYPE abap_boolean,
          is_same_country    TYPE abap_boolean.

    DATA iv_skip_glaccount2 TYPE abap_boolean.

ENDCLASS.

CLASS zcl_interco_taxbr IMPLEMENTATION.
  METHOD constructor.

    iv_skip_glaccount2 = i_skip_glaccount2.

    DATA range_departments TYPE RANGE OF zint_depto.
    DATA range_taxtype TYPE RANGE OF zi_intercotaxbritem-taxtype.
    DATA range_contingency TYPE RANGE OF zi_intercotaxbritem-contingency.

    range_departments = VALUE #( sign = 'I' option = 'EQ' ( low = ' ' ) ( low = i_department ) ).
    IF i_taxtype IS SUPPLIED.
      range_taxtype = VALUE #( ( sign = 'I' option = 'EQ' low = i_taxtype ) ).
    ENDIF.

    IF i_contingency IS SUPPLIED.
      range_contingency = VALUE #( ( sign = 'I' option = 'EQ' low = i_contingency ) ).
    ENDIF.

    SELECT DISTINCT providercompanycode, recipientcompanycode, product, department, \_items-taxtype,\_items-taxrate, \_items-glaccount1, 1 AS glaccount_int FROM zi_intercotaxbr
      WHERE providercompanycode = @i_providercompanycode
        AND recipientcompanycode = @i_recipientcompanycode
        AND product = @i_product
        AND department IN @range_departments
        AND validfrom <= @i_valid_at
        AND validto >= @i_valid_at
        AND isdeleted IS INITIAL
        AND \_items-taxtype IN @range_taxtype
        AND documenttype = @i_doctype
        AND \_items-contingency IN @range_contingency
        INTO TABLE @data.

    " in some scenarios we do not need the P&L Account (glaccount2)
    IF i_skip_glaccount2 = abap_false.
      SELECT DISTINCT providercompanycode, recipientcompanycode, product, department, \_items-taxtype,\_items-taxrate, \_items-glaccount2, 2 AS glaccount_int FROM zi_intercotaxbr
      WHERE providercompanycode = @i_providercompanycode
        AND recipientcompanycode = @i_recipientcompanycode
        AND product = @i_product
        AND department IN @range_departments
        AND validfrom <= @i_valid_at
        AND validto >= @i_valid_at
        AND isdeleted IS INITIAL
        AND documenttype = @i_doctype
        AND \_items-contingency IN @range_contingency
        APPENDING TABLE @data.
    ENDIF.

    IF data IS INITIAL.
      RAISE EXCEPTION TYPE zcx_interco_taxbr.
    ENDIF.

    SORT data BY providercompanycode recipientcompanycode product taxtype.
  ENDMETHOD.

  METHOD calculate_taxes_net.

    CLEAR: ev_total, et_glitems.

    DATA lineitem TYPE n LENGTH 6.
    DATA(_glitems) = it_glitems.

    SORT _glitems BY glaccountlineitem ASCENDING.
    SELECT MAX( glitems~glaccountlineitem ) FROM @_glitems AS glitems
      INTO @DATA(current_lineitem).

    lineitem = current_lineitem.

    LOOP AT it_glitems REFERENCE INTO DATA(glitem_in).
      DO lines( data ) TIMES.
        DATA(taxbr) = REF #( data[ sy-index ] ).
        lineitem += 1.

        APPEND INITIAL LINE TO et_glitems REFERENCE INTO DATA(glitem_out).
        glitem_out->glaccountlineitem = lineitem.
        glitem_out->documentitemtext = glitem_in->documentitemtext.
        glitem_out->assignmentreference = glitem_in->assignmentreference.
        glitem_out->profitcenter = glitem_in->profitcenter.
        IF taxbr->glaccount_ind = 2.
          glitem_out->costcenter = glitem_in->costcenter.
        ENDIF.
        glitem_out->partnercompany = glitem_in->partnercompany.
        glitem_out->material = glitem_in->material.
        glitem_out->glaccount = taxbr->glaccount.
        DO lines( glitem_in->_currencyamount ) TIMES.
          DATA(glitem_amount_in) = REF #( glitem_in->_currencyamount[ sy-index ] ).
          APPEND INITIAL LINE TO glitem_out->_currencyamount REFERENCE INTO DATA(glitem_amount_out).
          glitem_amount_out->currencyrole = glitem_amount_in->currencyrole.
          glitem_amount_out->currency = glitem_amount_in->currency.
          glitem_amount_out->journalentryitemamount = glitem_amount_in->journalentryitemamount * ( taxbr->taxrate / 100 ) * COND #( WHEN taxbr->glaccount_ind = 1 THEN -1 ELSE 1 ).
          glitem_amount_out->exchangerate = glitem_amount_in->exchangerate.
          ev_total += glitem_amount_out->journalentryitemamount.


          DATA(total) = VALUE ty_totals( currency_role = glitem_amount_out->currencyrole
                                         currency = glitem_amount_out->currency
                                         amount = glitem_amount_out->journalentryitemamount ).
          COLLECT total INTO et_totals.


          APPEND INITIAL LINE TO et_glitems_custom REFERENCE INTO DATA(glitem_out_custom).
          glitem_out_custom->* = CORRESPONDING  #( glitem_out->* ).
          glitem_out_custom->taxtype = taxbr->taxtype.
          glitem_out_custom->glaccount_origin = glitem_in->glaccount.

        ENDDO.

        IF iv_skip_glaccount2 = abap_true.
          lineitem += 1.

          APPEND INITIAL LINE TO et_glitems REFERENCE INTO DATA(glitem_out2).
          glitem_out2->* = CORRESPONDING #( DEEP glitem_out->* ).
          glitem_out2->glaccountlineitem = lineitem.
          glitem_out2->glaccount = glitem_in->glaccount.
          glitem_out2->costcenter = glitem_in->costcenter.
          DO lines( glitem_out2->_currencyamount ) TIMES.
            glitem_amount_out = REF #( glitem_out2->_currencyamount[ sy-index ] ).
            glitem_amount_out->journalentryitemamount = glitem_amount_out->journalentryitemamount * -1.
            ev_total += glitem_amount_out->journalentryitemamount.
            total = VALUE ty_totals( currency_role = glitem_amount_out->currencyrole
                                           currency = glitem_amount_out->currency
                                           amount = glitem_amount_out->journalentryitemamount ).
            COLLECT total INTO et_totals.
          ENDDO.

          APPEND INITIAL LINE TO et_glitems_custom REFERENCE INTO DATA(glitem_out_custom2).
          glitem_out_custom2->* = CORRESPONDING  #( glitem_out2->* ).
          glitem_out_custom2->taxtype = taxbr->taxtype.
          glitem_out_custom2->glaccount_origin = glitem_in->glaccount.

        ENDIF.


      ENDDO.
    ENDLOOP.

  ENDMETHOD.

  METHOD replace_accounts.

    DATA lineitem TYPE n LENGTH 6.
    DATA(_glitems) = it_glitems.

    LOOP AT it_glitems REFERENCE INTO DATA(glitem_in).

      TRY.
          DATA(taxbr) = REF #( data[ taxtype = glitem_in->taxtype glaccount_ind = 2 ] ).
          DATA(new_glaccount) = taxbr->glaccount.
        CATCH cx_sy_itab_line_not_found.
          CLEAR new_glaccount.
      ENDTRY.

      APPEND INITIAL LINE TO et_glitems REFERENCE INTO DATA(glitem_out).
      glitem_out->* = CORRESPONDING #( glitem_in->* ).
      IF glitem_in->glaccount_origin = glitem_in->glaccount.
        glitem_out->glaccount = new_glaccount.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD aggregate_glitems.
* Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento de posiciones por cuenta y centro de coste
    " Estructura auxiliar para sumar importes por moneda via COLLECT
    " (evita READ TABLE dentro de LOOP -> cumple ATC clean core).
    TYPES: BEGIN OF ty_amount_sum,
             currencyrole TYPE c LENGTH 2,
             currency     TYPE waers,
             exchangerate TYPE f,
             amount       TYPE i_journalentryitem-amountintransactioncurrency,
           END OF ty_amount_sum,
           tt_amount_sum TYPE SORTED TABLE OF ty_amount_sum
                              WITH UNIQUE KEY currencyrole currency exchangerate.

    DATA(lt_in) = ct_glitems.
    CLEAR ct_glitems.

    LOOP AT lt_in ASSIGNING FIELD-SYMBOL(<in>)
         GROUP BY ( glaccount           = <in>-glaccount
                    costcenter          = <in>-costcenter
                    profitcenter        = <in>-profitcenter
                    partnercompany      = <in>-partnercompany
                    material            = <in>-material
                    baseunit            = <in>-baseunit
                    assignmentreference = <in>-assignmentreference
                    documentitemtext    = <in>-documentitemtext )
         ASSIGNING FIELD-SYMBOL(<group>).

      APPEND INITIAL LINE TO ct_glitems ASSIGNING FIELD-SYMBOL(<out>).
      DATA(lv_first) = abap_true.
      DATA lt_amount_sum TYPE tt_amount_sum.
      CLEAR lt_amount_sum.

      LOOP AT GROUP <group> ASSIGNING FIELD-SYMBOL(<member>).
        IF lv_first = abap_true.
          <out> = <member>.
          CLEAR: <out>-_currencyamount, <out>-quantity.
          lv_first = abap_false.
        ENDIF.
        <out>-quantity = <out>-quantity + <member>-quantity.

        " Suma por moneda sin loop anidado: acceso por indice con DO + COLLECT
        DATA(lv_lines) = lines( <member>-_currencyamount ).
        DO lv_lines TIMES.
          ASSIGN <member>-_currencyamount[ sy-index ] TO FIELD-SYMBOL(<amt>).
          COLLECT VALUE ty_amount_sum(
            currencyrole = <amt>-currencyrole
            currency     = <amt>-currency
            exchangerate = <amt>-exchangerate
            amount       = <amt>-journalentryitemamount
          ) INTO lt_amount_sum.
        ENDDO.
      ENDLOOP.

      " Vuelca los importes sumados a la tabla anidada de salida
      DATA(lv_sum_lines) = lines( lt_amount_sum ).
      DO lv_sum_lines TIMES.
        ASSIGN lt_amount_sum[ sy-index ] TO FIELD-SYMBOL(<sum>).
        APPEND VALUE #(
          currencyrole           = <sum>-currencyrole
          currency               = <sum>-currency
          exchangerate           = <sum>-exchangerate
          journalentryitemamount = <sum>-amount
        ) TO <out>-_currencyamount.
      ENDDO.

    ENDLOOP.

    LOOP AT ct_glitems ASSIGNING FIELD-SYMBOL(<final>).
      <final>-glaccountlineitem = sy-tabix.
    ENDLOOP.
* Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento de posiciones por cuenta y centro de coste
  ENDMETHOD.


  METHOD use_new_aggregation.
** Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: switch A/B por usuario para pruebas comparativas
*    " ===================================================================
*    " SWITCH DE PRUEBAS A/B - BORRAR AL FINALIZAR LAS PRUEBAS.
*    " Los usuarios de esta lista ejecutan el CODIGO NUEVO (agrupamiento).
*    " Todos los demas (incluido el proceso de fondo) usan el codigo viejo.
*    " Al terminar las pruebas, reemplazar todo el cuerpo por:
*    "   rv_use_new = abap_true.
*    " ===================================================================
*    DATA(lt_usuarios_codigo_nuevo) = VALUE string_table(
**      ( |EXT_NIMINGUI| )
*      ( |EXT_OSCUGALD| )
*    ).
*
*    rv_use_new = xsdbool( line_exists(
*      lt_usuarios_codigo_nuevo[ table_line = sy-uname ] ) ).
** Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: switch A/B por usuario para pruebas comparativas

* Ini EXT_OSCUGALD 11.08.2026 - Fix F5727 TEMPORAL PRUEBAS: todos ejecutan agrupamiento
    " Durante pruebas ampliadas, TODOS los usuarios ejecutan el codigo nuevo.
    " (Antes: lista de usuarios habilitados. Al finalizar el proyecto, este metodo
    " y las llamadas se retiran y el agrupamiento queda incondicional.)
    rv_use_new = abap_true.
* Fin EXT_OSCUGALD 11.08.2026 - Fix F5727 TEMPORAL PRUEBAS: todos ejecutan agrupamiento
  ENDMETHOD.

ENDCLASS.
