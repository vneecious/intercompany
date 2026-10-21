CLASS zcl_proposal_bo_wt_post DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

* ext_oscugald - reclasificacion grossing up
    TYPES: BEGIN OF ty_journalentryitems,
             CompanyCode                 TYPE I_JournalEntry-CompanyCode,
             FiscalYear                  TYPE I_JournalEntry-FiscalYear,
             AccountingDocument          TYPE I_JournalEntry-AccountingDocument,
             DocumentDate                TYPE I_JournalEntry-DocumentDate,
             PostingDate                 TYPE I_JournalEntry-PostingDate,
             DocumentReferenceID         TYPE I_JournalEntry-DocumentReferenceID,
             exchangerate                TYPE I_JournalEntry-ExchangeRate,
             ledger                      TYPE I_JournalEntryItem-Ledger,
             referencedocumentitem       TYPE I_JournalEntryItem-ReferenceDocumentItem,
             glaccount                   TYPE I_JournalEntryItem-GLAccount,
             costcenter                  TYPE I_JournalEntryItem-CostCenter,
             profitcenter                TYPE I_JournalEntryItem-ProfitCenter,
             amountintransactioncurrency TYPE I_JournalEntryItem-AmountInTransactionCurrency,
             amountincompanycodecurrency TYPE I_JournalEntryItem-AmountInCompanyCodeCurrency,
             companycodecurrency         TYPE I_JournalEntryItem-CompanyCodeCurrency,
             transactioncurrency         TYPE I_JournalEntryItem-TransactionCurrency,
             amountinglobalcurrency      TYPE I_JournalEntryItem-AmountInGlobalCurrency,
             globalcurrency              TYPE I_JournalEntryItem-GlobalCurrency,
             sourceledger                TYPE I_JournalEntryItem-SourceLedger,
           END OF ty_journalentryitems.
    TYPES: tt_JOURNALENTRYITEMS TYPE STANDARD TABLE OF ty_journalentryitems WITH EMPTY KEY.
    TYPES: BEGIN OF ty_doc_account,
             validfrom            TYPE zi_intercoglacctdetermination-Validfrom,
             validto              TYPE zi_intercoglacctdetermination-validto,
             doctype              TYPE zi_intercoglacctdetermination-doctype,
             providercompanycode  TYPE zi_intercoglacctdetermination-providercompanycode,
             recipientcompanycode TYPE zi_intercoglacctdetermination-recipientcompanycode,
             product              TYPE zi_intercoglacctdetermination-product,
             department           TYPE zi_intercoglacctdetermination-department,
             pandlid              TYPE zi_intercoglacctdetermination-pandlid,
             tarifftype           TYPE zi_intercoglacctdetermination-tarifftype,
             operationtype        TYPE zi_intercoglacctdetermination-operationtype,
             glaccount1           TYPE zi_intercoglacctdetermination-glaccount1,
             glaccount2           TYPE zi_intercoglacctdetermination-glaccount2,
           END OF ty_doc_account.
    TYPES: tt_doc_account TYPE STANDARD TABLE OF ty_doc_account WITH EMPTY KEY.
    TYPES: gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post .
    TYPES: gsty_glitems TYPE LINE OF gsty_post-%param-_glitems .
    TYPES: gtty_glitems TYPE STANDARD TABLE OF gsty_glitems WITH EMPTY KEY.

    TYPES: BEGIN OF ty_itemorglacct,
             id             TYPE zi_intercoproposalitemorglacct-id,
             itemid         TYPE zi_intercoproposalitemorglacct-itemid,
             department     TYPE zi_intercoproposalitemorglacct-department,
             costcenter     TYPE zi_intercoproposalitemorglacct-costcenter,
             profitcenter   TYPE zi_intercoproposalitem-profitcenter,
             profitcentereq TYPE zi_intercoproposalitem-profitcentereq,
           END OF ty_itemorglacct.

    " Tipo de tabla estándar para el SELECT y pasaje de parámetros
    TYPES tt_itemorglacct TYPE STANDARD TABLE OF ty_itemorglacct WITH EMPTY KEY.
* ext_oscugald - reclasificacion grossing up
    TYPES:
      gtty_journalentry_post    TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
    TYPES:
      gtty_journalentry_reverse TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .

    DATA gta_journalentry_post TYPE gtty_journalentry_post .
    DATA gta_journalentry_reverse TYPE gtty_journalentry_reverse .
    DATA:
      gta_invoice_create     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create .
    DATA:
      gta_invoice_cancel     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~cancel .
    DATA:
      gtc_purchaseorder      TYPE TABLE FOR CREATE i_purchaseordertp_2 .
    DATA:
      gtc_poitem             TYPE TABLE FOR CREATE i_purchaseordertp_2\_purchaseorderitem .
    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .
    DATA gs_header_si TYPE zi_intercoproposal .
    DATA gtd_doc_bd TYPE gtty_doc .
*    DATA gv_parentdocumentkey   TYPE zfi_a_intrc_cpid-documentkey.
    DATA gt_doc_map_si TYPE gtty_doc .
    DATA gv_proposal_type TYPE zfi_a_intrc_cpd-documenttype .
    DATA gt_doc_map_db TYPE gtty_doc .
*    DATA lr_countries_uy TYPE RANGE OF land1.

*        !iv_documentkey         TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
*        !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
*        !iv_process             TYPE c OPTIONAL
*        !it_purchaseorder     LIKE gtc_purchaseorder OPTIONAL
*        !it_poitem            LIKE gtc_poitem OPTIONAL
    METHODS constructor
      IMPORTING
        !iv_doctype           TYPE zfi_a_intrc_cpid-documenttype OPTIONAL
        !is_header            TYPE zi_intercoproposal OPTIONAL
        !it_items             TYPE ztt_proposalitem_add OPTIONAL
        !it_bases             TYPE gtty_bases OPTIONAL
        !it_calc              TYPE gtty_calc OPTIONAL
        !it_doc               TYPE gtty_doc OPTIONAL
        !it_anul_doc          TYPE gtty_doc OPTIONAL
        !its_bases            TYPE gtsty_bases OPTIONAL
        !its_calc             TYPE gtsty_calc OPTIONAL
        !its_doc              TYPE gtsty_doc OPTIONAL
        !it_glaccount         TYPE ztt_proposal_reclassif OPTIONAL
        !its_glaccount        TYPE gtsty_glaccount OPTIONAL
        !iv_process           TYPE c OPTIONAL
        !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !it_doc_map           TYPE gtty_doc OPTIONAL
        !it_baogl             TYPE gtty_baogl OPTIONAL
        !its_baogl            TYPE gtsty_baogl OPTIONAL
        !iv_proposal_type     TYPE zfi_a_intrc_cpd-documenttype OPTIONAL.
  PROTECTED SECTION.
    METHODS preparedata REDEFINITION.
    METHODS exe_bo REDEFINITION .
    METHODS mapping_bo_sec REDEFINITION .
    METHODS mapping_reverse_sec REDEFINITION.
    METHODS preparedata_reverse REDEFINITION.
  PRIVATE SECTION.

*ext_oscugald - DF438 Asientos contables Uruguay
    " Reutilizamos la definición que ya tienes en el método principal para que coincida
    TYPES: BEGIN OF lty_with_item_aux,
             companycode                  TYPE bukrs,
             fiscalyear                   TYPE gjahr,
             accountingdocument           TYPE belnr_d,
             postingdate                  TYPE budat,
             documentdate                 TYPE bldat,
             exchangerate                 TYPE i_journalentry-exchangerate,
             withholdingtaxcode           TYPE i_withholdingtaxitem-withholdingtaxcode,
             whldgtaxbaseamtincocodecrcy  TYPE i_withholdingtaxitem-whldgtaxbaseamtincocodecrcy,
             whldgtaxbaseamtintransaccrcy TYPE i_withholdingtaxitem-whldgtaxbaseamtintransaccrcy,
             companycodecurrency          TYPE waers,
             documentcurrency             TYPE waers,
             whldgtaxrelevantpercent      TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent,
             withholdingtaxpercent        TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
             withholdingtaxpostingrule    TYPE i_extendedwhldgtaxcode-withholdingtaxpostingrule,
           END OF lty_with_item_aux,
           ltty_with_item_aux TYPE STANDARD TABLE OF lty_with_item_aux WITH EMPTY KEY.

    TYPES: BEGIN OF ty_wht_totals,
             wth_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
             wth_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency,
             companycode    TYPE bukrs,
             exchangerate   TYPE i_journalentry-exchangerate,
             postingdate    TYPE budat,
             documentdate   TYPE bldat,
             currency_co    TYPE waers,
             currency_doc   TYPE waers,
             found          TYPE abap_bool,
           END OF ty_wht_totals.
*ext_oscugald - DF438 Asientos contables Uruguay

    TYPES:
      BEGIN OF gty_total_item,
        id           TYPE zi_intercoproposalitem-id,
        itemid       TYPE zi_intercoproposalitem-item_id,
        costcenterd4 TYPE zi_intercoproposalitemorglacct-costcenterd4,
*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1: profitcenter en clave del total
*   Sin PC en la clave, un d4 compartido por varios PCs genera denominador cross-PC.
*   Cada PC recibe percentoftotal como fraccion del total compartido y la suma
*   por PC da 200%/300% en lugar de 100%. Con PC en la clave el total es por
*   (id, itemid, d4, PC) y percentoftotal suma exactamente 100000 dentro de cada PC.
        profitcenter TYPE zi_intercoproposalitem-profitcenter,
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1
        total        TYPE zi_intercoproposalitemorglacct-amountinglobalcurrency.
    TYPES: END OF gty_total_item .
    TYPES:
      BEGIN OF gty_item_sum,
        id             TYPE zi_intercoproposalitemorglacct-id,
        item_id        TYPE zi_intercoproposalitemorglacct-itemid,
        department     TYPE zi_intercoproposalitemorglacct-department,
        costcenterd4   TYPE zi_intercoproposalitemorglacct-costcenterd4,
        costcenter     TYPE zi_intercoproposalitemorglacct-costcenter,
        profitcenter   TYPE zi_intercoproposalitem-profitcenter,
        profitcentereq TYPE zi_intercoproposalitem-profitcentereq,
        percentoftotal TYPE p LENGTH 16 DECIMALS 8.
    TYPES: END OF gty_item_sum .
    TYPES:
      gtty_item_glacct TYPE STANDARD TABLE OF zi_intercoproposalitemorglacct .
    TYPES:
      gtty_total_item TYPE STANDARD TABLE OF gty_total_item .
    TYPES:
      gtty_item_sum TYPE STANDARD TABLE OF gty_item_sum.
    TYPES:
      gtty_glaccount TYPE RANGE OF i_journalentryitem-glaccount .
    TYPES:
      BEGIN OF gty_total_je,
        accountingdocument          TYPE i_journalentryitem-accountingdocument,
        companycode                 TYPE i_journalentryitem-companycode,
        fiscalyear                  TYPE i_journalentryitem-fiscalyear,
        glaccount                   TYPE i_journalentryitem-glaccount,
        profitcenter                TYPE i_journalentryitem-profitcenter,
        amountintransactioncurrency TYPE i_journalentryitem-amountintransactioncurrency,
        transactioncurrency         TYPE i_journalentryitem-transactioncurrency,
        amountinglobalcurrency      TYPE i_journalentryitem-amountinglobalcurrency,
        globalcurrency              TYPE i_journalentryitem-globalcurrency.
    TYPES END OF gty_total_je .

    TYPES:
      BEGIN OF gty_je_his,
        accountingdocument          TYPE i_journalentryitem-accountingdocument,
        companycode                 TYPE i_journalentryitem-companycode,
        fiscalyear                  TYPE i_journalentryitem-fiscalyear,
        glaccount                   TYPE i_journalentryitem-glaccount,
        profitcenter                TYPE i_journalentryitem-profitcenter,
        costcenter                  TYPE i_journalentryitem-costcenter,
        costcenterd4                TYPE zi_intercoproposalitemorglacct-costcenterd4,
        amountintransactioncurrency TYPE i_journalentryitem-amountintransactioncurrency,
        transactioncurrency         TYPE i_journalentryitem-transactioncurrency,
        amountinglobalcurrency      TYPE i_journalentryitem-amountinglobalcurrency,
        globalcurrency              TYPE i_journalentryitem-globalcurrency,
        partnercompany              TYPE i_journalentryitem-partnercompany,
        partnercountry              TYPE i_companycode-country,
        companycountry              TYPE i_companycode-country.
    TYPES END OF gty_je_his .

    TYPES:
      gtty_je_his TYPE STANDARD TABLE OF gty_je_his.


    TYPES:
      gtty_total_je TYPE STANDARD TABLE OF gty_total_je .
    TYPES:
      BEGIN OF gty_tvarvc_data,
        tarifftype_item_1   TYPE zint_a_md_glacct-tariff_type,
        tarifftype_item_2n  TYPE zint_a_md_glacct-tariff_type,
        glaccount_redondeo  TYPE i_withholdingtaxitem-glaccount,
        costcenter_redondeo TYPE zi_intercoproposalitemorglacct-costcenter,
        blart               TYPE i_journalentry-accountingdocumenttype,
        doctype             TYPE  zint_a_md_glacct-doc_type,
        glaccount_je        TYPE gtty_glaccount,
        glaccount_item_1    TYPE i_journalentryitem-glaccount,   "DF438 Asientos contables Uruguay
        glaccount_item_2n   TYPE i_journalentryitem-glaccount.   "DF438 Asientos contables Uruguay
    TYPES: END OF gty_tvarvc_data .
    TYPES:
      BEGIN OF gty_percent_je,
        accountingdocument TYPE i_journalentryitem-accountingdocument,
        companycode        TYPE i_journalentryitem-companycode,
        fiscalyear         TYPE i_journalentryitem-fiscalyear,
        glaccount          TYPE i_journalentryitem-glaccount,
        profitcenter       TYPE i_journalentryitem-profitcenter,
        percent            TYPE p LENGTH 16 DECIMALS 8.
    TYPES END OF gty_percent_je .
    TYPES:
      BEGIN OF gty_percent_his,
        accountingdocument TYPE i_journalentryitem-accountingdocument,
        companycode        TYPE i_journalentryitem-companycode,
        fiscalyear         TYPE i_journalentryitem-fiscalyear,
        glaccount          TYPE i_journalentryitem-glaccount,
        profitcenter       TYPE i_journalentryitem-profitcenter,
        costcenterd4       TYPE zi_intercoproposalitemorglacct-costcenterd4,
        percent            TYPE p LENGTH 16 DECIMALS 8.
    TYPES END OF gty_percent_his .
    TYPES:
      gtty_percent_je TYPE STANDARD TABLE OF gty_percent_je .
    TYPES:
      gtty_percent_his TYPE STANDARD TABLE OF gty_percent_his .

    CONSTANTS gc_tarifftype_item_1 TYPE zi_tvarvc-name VALUE 'ZWT_TARIFFTYPE_ITEM_1' ##NO_TEXT.
    CONSTANTS gc_tarifftype_item_2n TYPE zi_tvarvc-name VALUE 'ZWT_TARIFFTYPE_ITEM_2N' ##NO_TEXT.
    CONSTANTS gc_glaccount_redondeo TYPE zi_tvarvc-name VALUE 'ZWT_GLACCOUNT_REDONDEO' ##NO_TEXT.
    CONSTANTS gc_costcenter_redondeo TYPE zi_tvarvc-name VALUE 'ZWT_COSTCENTER_REDONDEO' ##NO_TEXT.
    CONSTANTS gc_blart TYPE zi_tvarvc-name VALUE 'ZWT_BLART' ##NO_TEXT.
    CONSTANTS gc_doctype TYPE zi_tvarvc-name VALUE 'ZWT_DOCTYPE' ##NO_TEXT.
    CONSTANTS gc_glaccount_je TYPE zi_tvarvc-name VALUE 'ZWT_GLACCONT_JE' ##NO_TEXT.
    CONSTANTS gc_glaccount_item_1 TYPE zi_tvarvc-name VALUE 'ZWT_GLACCOUNT_ITEM_1' ##NO_TEXT.     "DF438 Asientos contables Uruguay
    CONSTANTS gc_glaccount_item_2n TYPE zi_tvarvc-name VALUE 'ZWT_GLACCOUNT_ITEM_2N' ##NO_TEXT.   "DF438 Asientos contables Uruguay
    CONSTANTS gc_companycode_uy TYPE zi_tvarvc-name VALUE 'ZWT_COMPANYCODE_UY' ##NO_TEXT.         "DF438 Asientos contables Uruguay
    CONSTANTS gc_country TYPE zi_tvarvc-name VALUE 'ZWT_COUNTRY_250' ##NO_TEXT.                   "DF438 Asientos contables Uruguay
    CONSTANTS gc_provision_customer TYPE zint_tariff_type VALUE '93'.

    METHODS preparedata_so .
    METHODS preparedata_po .
    METHODS preparedata_recl. " ext_oscugald - reclasificacion grossing up
    METHODS preparedata_uy.   " ext_oscugald - DF438 Asientos contables Uruguay
    METHODS grossingup_reclassif
      RAISING zcx_calc_exit.
    METHODS journalentryitem
      IMPORTING
                !it_journalentryitem TYPE tt_JOURNALENTRYITEMS
                !is_doc_map          LIKE LINE OF gtd_doc_bd
                !it_doc_account      TYPE tt_doc_account
                !iv_glaccount1       TYPE zi_intercoglacctdetermination-glaccount1
                !it_itemorglacct     TYPE tt_itemorglacct
      EXPORTING
                et_glitems           TYPE gtty_glitems
      RAISING   zcx_calc_exit.
* ext_oscugald - reclasificacion grossing up
* ext_oscugald - DF438 Asientos contables Uruguay
    METHODS provision_retencion_uruguay
      IMPORTING it_doc_map_si TYPE gtty_doc OPTIONAL
      RAISING   zcx_calc_exit.
    METHODS:
      calculate_uruguay_wht
        IMPORTING is_doc_map       TYPE any " gt_doc_map_si line
                  it_with_item     TYPE ltty_with_item_aux
                  iv_perc_no_comp  TYPE p
        RETURNING VALUE(rs_totals) TYPE ty_wht_totals,

      get_item_sum_loop
        IMPORTING is_group               TYPE any
                  it_item_sum            TYPE gtty_item_sum
                  is_tvarvc_data         TYPE gty_tvarvc_data
                  is_glaccount_1         TYPE zi_intercoglacctdetermination-glaccount1
                  is_sitecode            TYPE any
                  iv_wth_amt_cocode      TYPE i_journalentryitem-amountincompanycodecurrency
                  iv_wth_amt_doc         TYPE i_journalentryitem-amountinglobalcurrency
                  iv_item_text           TYPE sgtxt
                  iv_exchangerate        TYPE i_journalentry-exchangerate
                  iv_partner_company     TYPE bukrs OPTIONAL
                  it_percent_je          TYPE gtty_percent_je
                  it_percent_his         TYPE gtty_percent_his
                  is_wht_line            TYPE lty_with_item_aux
*                  iv_tax_code            TYPE zde_witht
        CHANGING  ct_glitems             TYPE ANY TABLE
                  cv_position_num        TYPE int4
                  cv_totalpos_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency
                  cv_totalpos_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency.
* ext_oscugald - DF438 Asientos contables Uruguay
    METHODS get_tvarvc
      EXPORTING
        !iv_tvarvc_data TYPE gty_tvarvc_data .
    METHODS map_error
      IMPORTING
        !iv_id       TYPE symsgid
        !iv_number   TYPE symsgno
        !iv_severity TYPE if_abap_behv_message=>t_severity
        !iv_doc_key  TYPE zfi_a_intrc_cpd-documentkey
        !iv_doc_map  TYPE zi_intercoproposalitemdoc .
    METHODS get_percent_of_total
      CHANGING
        !ch_item_sum TYPE gtty_item_sum .
    METHODS get_percent_je
      IMPORTING
        !iv_doc_map_si   TYPE gtty_doc
        !iv_glaccount_je TYPE gtty_glaccount
      CHANGING
        !ch_percent_je   TYPE gtty_percent_je .
    METHODS get_percent_his
      IMPORTING
        !iv_doc_map_si   TYPE gtty_doc
*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033: get_percent_his necesita glaccount_je
*   Para docs AR clase IC (solo posiciones 134001 tipo X), el filtro
*   glaccounttype='P' OR 'N' deja lt_je vacio. Se agrega parametro para
*   incluir cuentas de ZWT_GLACCONT_JE como fuente alternativa.
        !iv_glaccount_je TYPE gtty_glaccount
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033
      CHANGING
        !ch_percent_his  TYPE gtty_percent_his .
ENDCLASS.



CLASS ZCL_PROPOSAL_BO_WT_POST IMPLEMENTATION.


  METHOD exe_bo.

    DATA lv_debug TYPE abap_boolean.
    DATA lo_parallel TYPE REF TO zcl_proposal_bo_wt_post_par.

    CHECK gtd_list_bo IS NOT INITIAL.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst(
      EXPORTING
        p_in_tab  = gtd_list_bo
        p_debug   = lv_debug
      IMPORTING
        p_out_tab = DATA(l_out_tab) ).

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>).

      IF <l_out>-inst IS NOT INITIAL.
        lo_parallel ?= <l_out>-inst.
        APPEND LINES OF lo_parallel->gt_doc_map_si TO me->gt_doc_map_db.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD mapping_reverse_sec.
    DATA: ld_today  TYPE d.

    IF gt_doc_map_si IS INITIAL.
      RETURN.
    ENDIF.

    SORT gt_doc_map_si BY documentkey companycode fiscalyear.
    DELETE ADJACENT DUPLICATES FROM gt_doc_map_si COMPARING documentkey companycode fiscalyear.

    SELECT i_journalentry~accountingdocument ,
           i_journalentry~companycode,
           i_journalentry~fiscalyear,
           postingdate
    FROM i_journalentry
    INNER JOIN @gt_doc_map_si AS documents
    ON  documents~documentkey  = i_journalentry~accountingdocument
    AND documents~companycode  = i_journalentry~companycode
    AND documents~fiscalyear   = i_journalentry~fiscalyear
   INTO TABLE @DATA(lt_posting_date).
    IF sy-subrc = 0.
      SORT lt_posting_date BY accountingdocument companycode fiscalyear.
    ENDIF.

    LOOP AT gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_doc>).

      TRY.
          DATA(ls_posting_date) = lt_posting_date[ accountingdocument = <fs_doc>-documentkey
                                                   fiscalyear         = <fs_doc>-fiscalyear
                                                   companycode        = <fs_doc>-companycode  ].
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      APPEND INITIAL LINE TO gta_journalentry_reverse ASSIGNING FIELD-SYMBOL(<jr>).
      <jr>-companycode = <fs_doc>-companycode.
      <jr>-fiscalyear  = <fs_doc>-fiscalyear.
      <jr>-accountingdocument = <fs_doc>-documentkey(10).
      <jr>-%param = VALUE #(  postingdate    = ls_posting_date-postingdate
                              reversalreason = '01'
                              createdbyuser  = cl_abap_context_info=>get_user_technical_name( )   ).

      APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.

      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-companycode }{ <fs_doc>-documentkey(10) }{ <fs_doc>-fiscalyear }|.
      <fs_doc_map>-parentdocumentkey  = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = <fs_doc>-documenttype.
      <fs_doc_map>-documenttype       = gv_proposal_type.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_wt_post_par( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
                                                         iv_doc_type    = gv_proposal_type
                                                         iv_documentkey = <fs_doc>-documentkey
                                                         it_doc_map     = gt_doc_map_db
                                                         it_je_reverse  = gta_journalentry_reverse ).
      APPEND lo_exe_bo TO gtd_list_bo.

      CLEAR: gt_doc_map_db, gta_journalentry_reverse.
    ENDLOOP.

    IF gtd_list_bo IS NOT INITIAL.
      exe_bo( ).
*      et_doc_map = me->gt_doc_map_db.  "ext_oscugald
      save_log( ).
      IF gt_doc_map_db[] IS INITIAL OR
          line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
          OR line_exists( gt_doc_map_db[ status = abap_false ] ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDIF.
*Ini EXT_OSCUGALD 2026-08-26 - Fix limpieza dummy reanulacion (SDFPSINIC-23362)
*   CORRECCION: <fs_old_dummy> es el documento ORIGINAL (documenttype=250,
*   documentkey sin prefijo). El registro a marcar isdeleted=X es su DUMMY
*   (documenttype=260, documentkey=DUMMY+...), construido igual que arriba.
*   NUNCA usar <fs_old_dummy>-documentkey/documenttype directo aqui, o se
*   marca por error el documento ORIGINAL en vez de su dummy.
*   mapping_reverse_sec nunca invoca mapping_doc_log (ese metodo solo se usa
*   en el flujo de creacion normal), por lo que el registro dummy del intento
*   anterior en ZFI_A_INTRC_CPD nunca se marca isdeleted=X ni se actualiza,
*   quedando "pegado" con status E aunque el nuevo documento de anulacion
*   se haya generado correctamente (status C). Se marca aqui explicitamente
*   el dummy anterior una vez confirmado que el nuevo documento fue exitoso.
      LOOP AT gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_old_dummy>).
        DATA(lv_old_dummy_key) = |DUMMY{ <fs_old_dummy>-companycode }{ <fs_old_dummy>-documentkey(10) }{ <fs_old_dummy>-fiscalyear }|.

        DATA(ls_old_dummy_check) = VALUE #( gt_doc_map_db[ parentdocumentkey = <fs_old_dummy>-documentkey
                                                            documenttype      = gv_proposal_type
                                                            status            = zcl_proposal_bo_abs=>c_document_status-commit ] OPTIONAL ).
        IF ls_old_dummy_check IS NOT INITIAL.
          APPEND INITIAL LINE TO gt_intrc_cpd ASSIGNING FIELD-SYMBOL(<fs_old_dummy_cpd>).
          <fs_old_dummy_cpd>-id             = <fs_old_dummy>-id.
          <fs_old_dummy_cpd>-documentkey    = lv_old_dummy_key.
          <fs_old_dummy_cpd>-documenttype   = gv_proposal_type.
          <fs_old_dummy_cpd>-companycode    = <fs_old_dummy>-companycode.
          <fs_old_dummy_cpd>-fiscalyear     = <fs_old_dummy>-fiscalyear.
          <fs_old_dummy_cpd>-isdeleted      = abap_true.
          <fs_old_dummy_cpd>-lastchangeby   = cl_abap_context_info=>get_user_technical_name( ).
          GET TIME STAMP FIELD <fs_old_dummy_cpd>-lastchangeat.
        ENDIF.
      ENDLOOP.
      IF gt_intrc_cpd IS NOT INITIAL.
        save_log( ).
      ENDIF.
*Fin EXT_OSCUGALD 2026-08-26 - Fix limpieza dummy reanulacion (SDFPSINIC-23362)
    ENDIF.

  ENDMETHOD.


  METHOD mapping_bo_sec.

    TYPES: lsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           lsty_glitems TYPE LINE OF lsty_post-%param-_glitems.

    DATA:
      lt_doc_map_log         TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
      lv_totalpos_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency,
      lv_totalpos_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
      lv_amt_doc             TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_max             TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_cocode          TYPE i_journalentryitem-amountincompanycodecurrency,
*      lv_ali_grossup         TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
      lv_ali_grossup         TYPE p LENGTH 7 DECIMALS 6,
*      lv_perc_wth            TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
      lv_perc_wth            TYPE p LENGTH 7 DECIMALS 6,
      lv_part_to_wth         TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent,
      lv_costcenter          TYPE zi_intercoproposalitemorglacct-costcenter,
      lv_doc_key             TYPE zfi_a_intrc_cpd-documentkey,
      lv_company_item        TYPE i_journalentry-companycode,
      lt_glitems             TYPE lsty_post-%param-_glitems,
      lv_status_log          TYPE zfi_a_intrc_cpdl-msgty,
      lv_perc_no_comp        TYPE zi_intercocompanyrelprodrate-taxcredit,
      lt_item_sum            TYPE gtty_item_sum,
      lv_cc_code             TYPE zde_cc_code,
      lv_error               TYPE abap_bool,
      lv_cid                 TYPE abp_behv_cid,
      lv_firstday            TYPE datum,
      lv_position_num        TYPE int4,
      lv_item_text           TYPE sgtxt,
      ls_tvarvc_data         TYPE gty_tvarvc_data,
      lt_percent_je          TYPE gtty_percent_je,
      lt_percent_his         TYPE gtty_percent_his,
      lv_tabix               TYPE sy-tabix,
      lv_index_mayor         TYPE sy-tabix,
      lv_account             TYPE hkont.

    IF gv_process <> zcl_boproposal_tools=>gc_create_doc.
      RETURN.
    ENDIF.

    lv_firstday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01|.
    TRY.
        DATA(lv_lastday) = zcl_interco_utils=>rp_last_day_of_months(
          EXPORTING
            day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
      CATCH cx_sy_conversion_no_date INTO DATA(exc).
        lv_lastday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod }31|.
    ENDTRY.

* EXT_OSCUGALD - DF438 Asientos contables Uruguay
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Provisión Retención Prestadora (ID 250 - Uruguay)
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    IF gv_proposal_type EQ zcl_proposal_bo_abs=>c_document_type-journalentry_ic. " Valor 250
      " Determinación de cuentas específica para Uruguay (DF438)

      SELECT SINGLE @abap_true
        FROM zi_intercoglacctdetermination
        WHERE validfrom           <= @lv_lastday
          AND validto             >= @lv_lastday
          AND providercompanycode  = @gs_header-providercompanycode
          AND doctype              = 'AR'
          AND product              = @gs_header-product
          AND isdeleted           IS INITIAL
          AND tarifftype           = @gc_provision_customer
        INTO @DATA(lv_is_provision_93).

      IF lv_is_provision_93 = abap_true.
        " Leer países permitidos de TVARVC
        SELECT sign, opti, low, high
          FROM zi_tvarvc
          WHERE name = @gc_country
            AND type = 'S'
          INTO TABLE @DATA(lt_tvarvc_raw).

        DATA lr_countries_uy TYPE RANGE OF land1.
        lr_countries_uy = VALUE #( FOR row IN lt_tvarvc_raw
                                      ( sign   = row-sign
                                        option = row-opti
                                        low    = CONV land1( row-low )
                                        high   = CONV land1( row-high ) ) ).

        " Construir tabla filtrada LOCAL — gt_doc_map_si nunca se modifica
        DATA lt_doc_map_uy TYPE gtty_doc.
        IF lr_countries_uy IS NOT INITIAL.
          SORT gtd_items_add BY id item_id itembasis_id itemcalc_id.
          LOOP AT gt_doc_map_si INTO DATA(ls_map_uy).
            TRY.
                DATA(ls_item_uy) = gtd_items_add[ id = ls_map_uy-id  item_id = ls_map_uy-item_id
                                                  itembasis_id = ls_map_uy-itembasis_id
                                                  itemcalc_id  = ls_map_uy-itemcalc_id ].
                IF ls_item_uy-recipientcountry IN lr_countries_uy.
                  APPEND ls_map_uy TO lt_doc_map_uy.
                ENDIF.
              CATCH cx_sy_itab_line_not_found.
                CONTINUE.
            ENDTRY.
          ENDLOOP.
        ENDIF.

        IF lt_doc_map_uy IS INITIAL. RETURN. ENDIF.

        me->provision_retencion_uruguay( it_doc_map_si = lt_doc_map_uy ).
        et_doc_map = me->gt_doc_map_db.
        RETURN.
      ELSE.
        RETURN.
      ENDIF.
    ENDIF.
* EXT_OSCUGALD - DF438 Asientos contables Uruguay
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
* EXT_OSCUGALD - Reclasificación Grossing Up Prestataria
    IF gv_proposal_type EQ zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.
      DATA(doc_account_pp) = NEW zcl_interco_doc_glaccount(
       i_doctype               = 'PP'
       i_product               = gs_header-product
       i_provider_company_code = gs_header-providercompanycode
       i_valid_at              = lv_lastday ).

      IF doc_account_pp->data IS INITIAL.
        "Si el documento 200 no tiene en determinación de cuentas tipo de documento PP, no tiene que crear recla grossing up 230
        RETURN.
      ELSE.
        me->grossingup_reclassif( ).
        et_doc_map = me->gt_doc_map_db.
        RETURN.
      ENDIF.

    ENDIF.
* EXT_OSCUGALD - Reclasificación Grossing Up Prestataria

    SELECT
    providercompanycode,
    recipientcompanycode,
    product,
    taxcredit
    FROM zi_intercocompanyrelprodrate
    FOR ALL ENTRIES IN @gtd_items_add
    WHERE providercompanycode  = @gtd_items_add-providercompanycode
      AND recipientcompanycode = @gtd_items_add-recipientcompanycode
      AND product              = @gtd_items_add-product
      AND validfrom <= @lv_firstday
      AND validto   >= @lv_lastday
      AND isdeleted = @space
    INTO TABLE @DATA(lt_relprodrate).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

    me->get_tvarvc( IMPORTING iv_tvarvc_data = ls_tvarvc_data ).

    IF gt_doc_map_si IS NOT INITIAL.

      SELECT je~companycode,
             je~fiscalyear,
             je~accountingdocument,
             je~originalreferencedocument,
             je~postingdate,
             je~documentdate,
             je~exchangerate,
             wt~withholdingtaxcode,
             wt~whldgtaxbaseamtincocodecrcy,
             wt~whldgtaxbaseamtintransaccrcy,
             wt~companycodecurrency,
             wt~documentcurrency,
             ext~whldgtaxrelevantpercent,
             ext~withholdingtaxpercent,
             ext~withholdingtaxpostingrule
        FROM i_journalentry              WITH PRIVILEGED ACCESS AS je
        INNER JOIN i_withholdingtaxitem  WITH PRIVILEGED ACCESS AS wt
        ON je~companycode         = wt~companycode
        AND je~accountingdocument = wt~accountingdocument
        AND je~fiscalyear         = wt~fiscalyear
        INNER JOIN i_extendedwhldgtaxcode WITH PRIVILEGED ACCESS AS ext
        ON  ext~country             = wt~country
        AND ext~withholdingtaxtype  = wt~withholdingtaxtype
        AND ext~withholdingtaxcode  = wt~withholdingtaxcode
        FOR ALL ENTRIES IN @gt_doc_map_si
        WHERE je~companycode        = @gt_doc_map_si-companycode
        AND   je~fiscalyear         = @gt_doc_map_si-fiscalyear
        AND   je~accountingdocument = @gt_doc_map_si-documentkey(10)
        INTO TABLE @DATA(lt_with_item).
      IF sy-subrc = 0.

        IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
          DELETE lt_with_item WHERE withholdingtaxpostingrule = '1'.
        ENDIF.

        IF lt_with_item IS NOT INITIAL.

          SORT lt_with_item BY companycode fiscalyear accountingdocument.

          me->get_percent_of_total( CHANGING ch_item_sum = lt_item_sum ).

          me->get_percent_je( EXPORTING iv_doc_map_si   = gt_doc_map_si
                                        iv_glaccount_je = ls_tvarvc_data-glaccount_je
                              CHANGING  ch_percent_je   = lt_percent_je ).

*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033: pasar glaccount_je a get_percent_his
          me->get_percent_his( EXPORTING iv_doc_map_si   = gt_doc_map_si
                                         iv_glaccount_je = ls_tvarvc_data-glaccount_je
                               CHANGING  ch_percent_his  = lt_percent_his ).
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033

          DATA(doc_account) = NEW zcl_interco_doc_glaccount(
            i_doctype               = ls_tvarvc_data-doctype
            i_product               = gs_header-product
            i_provider_company_code = gs_header-providercompanycode
            i_valid_at              = lv_lastday ).

        ENDIF.

      ENDIF.

      SELECT companycode,
             internalcode
      FROM zi_intercocompanycode
      FOR ALL ENTRIES IN  @gt_doc_map_si
      WHERE companycode = @gt_doc_map_si-companycode
      INTO TABLE @DATA(lt_sitecode).
      IF sy-subrc = 0.
        SORT lt_sitecode BY companycode.
      ENDIF.

    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    SORT gt_doc_map_si BY documentkey.
    SORT gtd_items_add BY id item_id itembasis_id itemcalc_id.

    LOOP AT gt_doc_map_si INTO DATA(ls_doc_map) GROUP BY ls_doc_map-documentkey.

      TRY.
          DATA(ls_item_1) = gtd_items_add[ id           = ls_doc_map-id
                                           item_id      = ls_doc_map-item_id
                                           itembasis_id = ls_doc_map-itembasis_id
                                           itemcalc_id  = ls_doc_map-itemcalc_id ] .

**********************************************************************
          IF gv_proposal_type EQ zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.  "190
*         "BRF Taxcode
            DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
            DATA tax_code TYPE c LENGTH 2.

            IF ls_tvarvc_data-doctype EQ zcl_interco_doc_glaccount=>co_doc_type-ar.
              brf_helper->get_tax_code(
                EXPORTING
                  iv_provider   = gs_header-providercompanycode
                  iv_recipient  = ls_item_1-recipientcompanycode
                  iv_product    = gs_header-product
                IMPORTING
                  ev_taxcode_ar = tax_code
              ).
*            ELSEIF ls_tvarvc_data-doctype EQ zcl_interco_doc_glaccount=>co_doc_type-accural_ap.
*              brf_helper->get_tax_code(
*                EXPORTING
*                  iv_provider   = gs_header-providercompanycode
*                  iv_recipient  = ls_item_1-recipientcompanycode
*                  iv_product    = gs_header-product
*                IMPORTING
*                  ev_taxcode_ap = tax_code
*              ).
            ENDIF.
          ENDIF.
**********************************************************************

          DATA(ls_relprodrate) = VALUE #( lt_relprodrate[ providercompanycode  = ls_item_1-providercompanycode
                                                          recipientcompanycode = ls_item_1-recipientcompanycode
                                                          product              = ls_item_1-product ] OPTIONAL ).

          IF ls_relprodrate-taxcredit = 100.

            lt_doc_map_log = VALUE #( ( %msg = new_message( id         = 'ZINT_MSG_INTERCO_CP'
                                                            number     = '026'
                                                            severity   = if_abap_behv_message=>severity-information
                                                            v1         = ls_doc_map-documentkey ) ) ).

            lv_doc_key = ls_doc_map-documentkey(10).

            mapping_doc_log( EXPORTING iv_dockey      = lv_doc_key
                                       iv_companycode = ls_doc_map-companycode
                                       iv_fiscalyear  = ls_doc_map-fiscalyear
                                       iv_doctype     = ls_doc_map-documenttype
                                       it_reported    = lt_doc_map_log
                             CHANGING  ct_map_id_doc  = gt_doc_map_si
                                       cv_status      = lv_status_log ).

            CLEAR: lt_doc_map_log, lv_doc_key, ls_relprodrate.
            CONTINUE.

          ENDIF.

          lv_perc_no_comp = 100 - ls_relprodrate-taxcredit.
          lv_perc_no_comp = lv_perc_no_comp / 100.

          LOOP AT lt_with_item ASSIGNING FIELD-SYMBOL(<lfs_with_item>) WHERE  companycode        = ls_doc_map-companycode
                                                                       AND    fiscalyear         = ls_doc_map-fiscalyear
                                                                       AND    accountingdocument = ls_doc_map-documentkey(10). "#EC CI_NESTED

            DATA lv_wth_amt_cocode LIKE <lfs_with_item>-whldgtaxbaseamtincocodecrcy.
            DATA lv_wth_amt_doc    LIKE <lfs_with_item>-whldgtaxbaseamtintransaccrcy.

            <lfs_with_item>-withholdingtaxpercent   = <lfs_with_item>-withholdingtaxpercent   / 100.
            <lfs_with_item>-whldgtaxrelevantpercent = <lfs_with_item>-whldgtaxrelevantpercent / 100.

            lv_ali_grossup   = <lfs_with_item>-withholdingtaxpercent / ( 1 - <lfs_with_item>-withholdingtaxpercent ).
            lv_part_to_wth   = <lfs_with_item>-whldgtaxrelevantpercent.

            IF <lfs_with_item>-withholdingtaxpostingrule = '2'.
              lv_perc_wth = lv_ali_grossup.
            ELSE.
              lv_perc_wth = <lfs_with_item>-withholdingtaxpercent.
            ENDIF.

            lv_wth_amt_cocode  += <lfs_with_item>-whldgtaxbaseamtincocodecrcy  * lv_part_to_wth * lv_perc_wth * lv_perc_no_comp.
            lv_wth_amt_doc     += <lfs_with_item>-whldgtaxbaseamtintransaccrcy * lv_part_to_wth * lv_perc_wth * lv_perc_no_comp.

            DATA(lv_company)      = <lfs_with_item>-companycode.
            DATA(lv_exchangerate) = <lfs_with_item>-exchangerate.
            DATA(lv_flag) = abap_true.

          ENDLOOP.

          IF lv_flag = abap_false.

            lt_doc_map_log = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                            number   = '025'
                                                            severity = if_abap_behv_message=>severity-information
                                                            v1       = ls_doc_map-documentkey ) ) ).

            lv_doc_key = ls_doc_map-documentkey(10).

            mapping_doc_log( EXPORTING iv_dockey      = lv_doc_key
                                       iv_companycode = ls_doc_map-companycode
                                       iv_fiscalyear  = ls_doc_map-fiscalyear
                                       iv_doctype     = ls_doc_map-documenttype
                                       it_reported    = lt_doc_map_log
                             CHANGING  ct_map_id_doc  = gt_doc_map_si
                                       cv_status      = lv_status_log ).

            CLEAR: lt_doc_map_log, lv_doc_key, ls_relprodrate, lv_perc_no_comp, lv_flag.
            CONTINUE.

          ENDIF.

          DATA(ls_sitecode) = VALUE #( lt_sitecode[ companycode  = lv_company ] OPTIONAL ).
          IF ls_sitecode-internalcode IS INITIAL.

            lv_doc_key  = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
            me->map_error(
              iv_id       = 'ZINT_MSG_INTERCO_CP'
              iv_number   = '27'
              iv_severity = if_abap_behv_message=>severity-error
              iv_doc_key  = lv_doc_key
              iv_doc_map  = ls_doc_map ).

            lv_error = abap_true.
            CONTINUE.

          ENDIF.

          DATA(ls_item_dept) = VALUE #( lt_item_sum[ id       = ls_doc_map-id
                                                     item_id  = ls_doc_map-item_id ] OPTIONAL ).

          doc_account->get( EXPORTING i_tarifftype = ls_tvarvc_data-tarifftype_item_1
                                      i_department = ls_item_dept-department
                            RECEIVING result       = DATA(ls_glaccount_1) ).

          CASE gv_proposal_type.
            WHEN zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
              lv_company_item = ls_item_1-providercompanycode.
            WHEN zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
              lv_company_item = ls_item_1-recipientcompanycode.
          ENDCASE.

          lv_item_text = |{ gs_header-providercompanycode }-{ ls_item_1-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.

          "item 1
          lv_position_num += 1.
          DATA(ls_glitems) = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
                                                 partnercompany      = lv_company_item
                                                 glaccount           = |{ ls_glaccount_1-glaccount1 ALPHA = IN }|
                                                 documentitemtext    = lv_item_text
                                                 assignmentreference = gs_header-productname
                                                 material            = gs_header-product
                                                 TaxCode             = tax_code
                                                 _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                   THEN lv_wth_amt_cocode * -1
                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                   THEN lv_wth_amt_cocode )
                                                                                  currency               = <lfs_with_item>-companycodecurrency
                                                                                  exchangerate           = lv_exchangerate
                                                                                  currencyrole           = '10'   )
                                                                                ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                   THEN lv_wth_amt_doc * -1
                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                   THEN lv_wth_amt_doc )
                                                                                  currency               = <lfs_with_item>-documentcurrency
                                                                                  exchangerate           = lv_exchangerate
                                                                                  currencyrole           = '00'   ) )  ).

          APPEND ls_glitems TO lt_glitems.
          CLEAR ls_glitems.

          lv_totalpos_amt_doc    = lv_wth_amt_doc    * -1.
          lv_totalpos_amt_cocode = lv_wth_amt_cocode * -1.

          CLEAR: lv_tabix, lv_amt_max, lv_index_mayor.
          lv_tabix = 1.

          LOOP AT GROUP ls_doc_map INTO DATA(ls_group).

*  Items 2 to N
            LOOP AT lt_item_sum INTO DATA(ls_item_sum)  WHERE id      = ls_group-id
                                                        AND   item_id = ls_group-item_id. "#EC CI_NESTED

***              lv_tabix = lv_tabix + 1.  "ext_oscugald redondeo

              DATA(lo_brf_cost) = NEW zcl_interco_brf_wht( ).
              lo_brf_cost->get_cc_code( EXPORTING iv_product      = gs_header-product
*                                                  iv_cuenta       = ls_glaccount_2-glaccount1
                                                  iv_cc_origen    = ls_item_sum-costcenterd4
                                                  iv_departamento = ls_item_sum-department
                                                  iv_tipo_doc     = ls_tvarvc_data-doctype
                                        RECEIVING rv_cc_code      = lv_cc_code ).

              IF lv_cc_code IS INITIAL.

                lv_doc_key  = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
                me->map_error(
                  iv_id       = 'ZINT_MSG_INTERCO_CP'
                  iv_number   = '28'
                  iv_severity = if_abap_behv_message=>severity-error
                  iv_doc_key  = lv_doc_key
                  iv_doc_map  = ls_doc_map ).

                lv_error = abap_true.
*                EXIT.

              ENDIF.

              doc_account->get( EXPORTING i_tarifftype = ls_tvarvc_data-tarifftype_item_2n
                                          i_department = ls_item_sum-department
                                RECEIVING result       = DATA(ls_glaccount_2) ).

              CLEAR lv_cc_code.
              "Clave completa
              lo_brf_cost->get_cc_code( EXPORTING iv_product      = gs_header-product
                                                  iv_cuenta       = ls_glaccount_2-glaccount1
                                                  iv_cc_origen    = ls_item_sum-costcenterd4
                                                  iv_departamento = ls_item_sum-department
                                                  iv_tipo_doc     = ls_tvarvc_data-doctype
                                        RECEIVING rv_cc_code      = lv_cc_code ).

              IF lv_cc_code IS INITIAL.
                "Clave sin cuenta
                lo_brf_cost->get_cc_code( EXPORTING iv_product      = gs_header-product
                                                    iv_cc_origen    = ls_item_sum-costcenterd4
                                                    iv_departamento = ls_item_sum-department
                                                    iv_tipo_doc     = ls_tvarvc_data-doctype
                                          RECEIVING rv_cc_code      = lv_cc_code ).
              ENDIF.
              IF lv_cc_code IS INITIAL.
                "Clave sin material
                lo_brf_cost->get_cc_code( EXPORTING iv_cuenta       = ls_glaccount_2-glaccount1
                                                    iv_cc_origen    = ls_item_sum-costcenterd4
                                                    iv_departamento = ls_item_sum-department
                                                    iv_tipo_doc     = ls_tvarvc_data-doctype
                                          RECEIVING rv_cc_code      = lv_cc_code ).
              ENDIF.
              IF lv_cc_code IS INITIAL.
                "Clave simple (sin material y sin cuenta)
                lo_brf_cost->get_cc_code( EXPORTING iv_cc_origen    = ls_item_sum-costcenterd4
                                                    iv_departamento = ls_item_sum-department
                                                    iv_tipo_doc     = ls_tvarvc_data-doctype
                                          RECEIVING rv_cc_code      = lv_cc_code ).
              ENDIF.

              IF lv_cc_code IS INITIAL.

                lv_doc_key  = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
                me->map_error(
                  iv_id       = 'ZINT_MSG_INTERCO_CP'
                  iv_number   = '28'
                  iv_severity = if_abap_behv_message=>severity-error
                  iv_doc_key  = lv_doc_key
                  iv_doc_map  = ls_doc_map ).

                lv_error = abap_true.
                EXIT.

              ENDIF.
**** INICIO  CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10
*              IF ls_item_sum-profitcentereq IS NOT INITIAL.
*                ls_item_sum-profitcenter = ls_item_sum-profitcentereq.
*                ls_item_sum-profitcenter  = |{ ls_item_sum-profitcenter ALPHA = IN  }|.
*              ENDIF.
**** FIN CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10

*Ini EXT_OSCUGALD 03.06.2026 - Fix RW033: fallback profitcentereq cuando PC crudo no tiene match
*   Causa raíz: GET_PERCENT_OF_TOTAL remapea los hijos de la jerarquía ZICEQ
*   (ej. 631/635/636/637 → 630) via profitcentereq, pero percent_je/percent_his
*   usan el PC crudo de ACDOCA. Cuando ls_item_sum-profitcenter (remapeado) no
*   tiene entry en lt_percent_je, el CONTINUE original descartaba la posición
*   silenciosamente: la línea tariff 92 nunca se generaba, su porción de retención
*   quedaba huérfana y lv_totalpos_amt_doc arrastraba el residuo. Como el bloque
*   de redondeo solo absorbe |saldo| <= 1 o signos opuestos, un residuo de 70/680/483
*   USD del mismo signo no entraba en ninguna rama → BKPFF rechazaba con RW033.
*   Fix: si el PC crudo no tiene match, reintentar con profitcentereq (PC padre ZICEQ).
*   Solo si tampoco ese tiene entry se ejecuta CONTINUE (caso realmente sin datos).
              TRY.
                  DATA(ls_percent_je) = VALUE #( lt_percent_je[ accountingdocument = ls_group-documentkey(10)
                                                                companycode       = ls_group-companycode
                                                                fiscalyear        = ls_group-fiscalyear
                                                                profitcenter      = ls_item_sum-profitcenter ] ).
                CATCH cx_sy_itab_line_not_found.
                  TRY.
                      ls_percent_je = VALUE #( lt_percent_je[ accountingdocument = ls_group-documentkey(10)
                                                              companycode        = ls_group-companycode
                                                              fiscalyear         = ls_group-fiscalyear
                                                              profitcenter       = ls_item_sum-profitcentereq ] ).
                    CATCH cx_sy_itab_line_not_found.
                      CONTINUE.
                  ENDTRY.
              ENDTRY.
*Fin EXT_OSCUGALD 03.06.2026 - Fix RW033

              DATA(ls_percent_his) = VALUE #( lt_percent_his[ accountingdocument  = ls_group-documentkey(10)
                                                               companycode        = ls_group-companycode
                                                               fiscalyear         = ls_group-fiscalyear
                                                               profitcenter       = ls_item_sum-profitcenter
                                                               costcenterd4       = ls_item_sum-costcenterd4 ] OPTIONAL ).


              lv_amt_cocode = ( ( lv_wth_amt_cocode * ls_percent_je-percent ) / 100000  * ( ls_item_sum-percentoftotal / 100000 ) ).
              lv_amt_doc    = ( ( lv_wth_amt_doc    * ls_percent_je-percent ) / 100000  * ( ls_item_sum-percentoftotal / 100000 ) ).

*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033: ignorar percent_his con costcenterd4=0
*   La cuenta 134001 (balance IC) no tiene CeCo -> costcenterd4=0 siempre.
*   Un percent_his con costcenterd4=0 no aporta informacion de distribucion real.
*   Con Capa1 aplicada, percent_je x percentoftotal ya suma 100% exacto.
*   Para docs AI con P&L: percent_his siempre tiene costcenterd4 real (1 o 3)
*   y el lookup matchea normalmente -> sin cambio de comportamiento.
*              IF ls_percent_his IS NOT INITIAL AND ls_percent_his-costcenterd4 <> 0.
*                lv_amt_cocode = lv_amt_cocode * ( ls_percent_his-percent / 100000 ).
*                lv_amt_doc    = lv_amt_doc    * ( ls_percent_his-percent / 100000 ).
*              ENDIF.
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033
*   EXT_OSCUGALD 07.06.2026 - Fix RW033: percent_his eliminado con Capa1 activa
*   Con Capa1, percentoftotal suma 100% por PC -> percent_je x percentoftotal = 100%.
*   Aplicar percent_his adicionalmente desbalancea el resultado para docs AI.
*   Para docs IC (percent_his vacio) ya cerraba. Para AI rompia. Se elimina.

              lv_position_num += 1.
              ls_glitems = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
                                               partnercompany      = lv_company_item
                                               glaccount           = |{ ls_glaccount_2-glaccount1 ALPHA = IN }|
                                               documentitemtext    = lv_item_text
                                               assignmentreference = gs_header-productname
                                               material            = gs_header-product
                                               TaxCode             = tax_code
                                               _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                 THEN lv_amt_cocode
                                                                                                                 WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                 THEN lv_amt_cocode * -1 )
                                                                                currency               = <lfs_with_item>-companycodecurrency
                                                                                exchangerate           = lv_exchangerate
                                                                                currencyrole           = '10'  )
                                                                              ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                 THEN lv_amt_doc
                                                                                                                 WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                 THEN lv_amt_doc * -1 )
                                                                                currency               = <lfs_with_item>-documentcurrency
                                                                                exchangerate           = lv_exchangerate
                                                                                currencyrole           = '00'   ) )
                                               costcenter          =   |{ lv_cc_code }{ ls_sitecode-internalcode }{ ls_item_sum-profitcenter ALPHA = OUT }| ).

              APPEND ls_glitems TO lt_glitems.
              CLEAR ls_glitems.
              lv_tabix = lv_tabix + 1.
              IF lv_amt_doc > lv_amt_max.
                lv_amt_max = lv_amt_doc.
                lv_index_mayor = lv_tabix.
              ENDIF.

              lv_totalpos_amt_doc    = lv_totalpos_amt_doc    + lv_amt_doc.
              lv_totalpos_amt_cocode = lv_totalpos_amt_cocode + lv_amt_cocode.

              CLEAR: lv_amt_doc, lv_amt_cocode, ls_percent_je, ls_percent_his.

            ENDLOOP.

*Ini EXT_OSCUGALD 04.02.2026 - Garantizar variable redondeo por signos nunca sea cero.
            IF lv_index_mayor IS INITIAL.
              lv_index_mayor = lines( lt_glitems ).
            ENDIF.
*Fin EXT_OSCUGALD 04.02.2026 - Garantizar variable redondeo por signos nunca sea cero.

            APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
            <fs_doc_map>-id                 = ls_group-id.
            <fs_doc_map>-item_id            = ls_group-item_id.
            <fs_doc_map>-itembasis_id       = ls_group-itembasis_id.
            <fs_doc_map>-itemcalc_id        = ls_group-itemcalc_id.
            <fs_doc_map>-documentkey        = |DUMMY{ ls_group-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
            <fs_doc_map>-parentdocumentkey  = ls_group-documentkey(10).
            <fs_doc_map>-fiscalyear         = ls_group-fiscalyear.
            <fs_doc_map>-companycode        = ls_group-companycode.

            CASE gv_proposal_type.
              WHEN zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
                <fs_doc_map>-documenttype       = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
                <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase.
              WHEN zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
                <fs_doc_map>-documenttype       = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
                <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-je_sales.
            ENDCASE.

          ENDLOOP.

*       Redondeo en donde las monedas quedan en distinto signo, se le descuentan de la posición con mayor valor.
          IF ( lv_totalpos_amt_doc < 0 AND lv_totalpos_amt_cocode > 0 ) OR ( lv_totalpos_amt_doc > 0 AND lv_totalpos_amt_cocode < 0 ).

            ASSIGN lt_glitems[ lv_index_mayor ] TO FIELD-SYMBOL(<lfs_line>).
            IF sy-subrc = 0.

              ASSIGN <lfs_line>-_currencyamount[ currency = <lfs_with_item>-companycodecurrency ] TO FIELD-SYMBOL(<lfs_cocode>).
              IF sy-subrc = 0.

                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
                  <lfs_cocode>-journalentryitemamount = <lfs_cocode>-journalentryitemamount - lv_totalpos_amt_cocode.
                ENDIF.

                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
                  <lfs_cocode>-journalentryitemamount = <lfs_cocode>-journalentryitemamount - ( lv_totalpos_amt_cocode * -1 ).
                ENDIF.

              ENDIF.

              ASSIGN <lfs_line>-_currencyamount[ currency = <lfs_with_item>-documentcurrency ] TO FIELD-SYMBOL(<lfs_doc>).
              IF sy-subrc = 0.

                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
                  <lfs_doc>-journalentryitemamount = <lfs_doc>-journalentryitemamount - lv_totalpos_amt_doc.
                ENDIF.

                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
                  <lfs_doc>-journalentryitemamount = <lfs_doc>-journalentryitemamount - ( lv_totalpos_amt_doc ) * -1.
                ENDIF.

              ENDIF.

            ENDIF.

*           Posición de redondeo
          ELSEIF ( lv_totalpos_amt_doc    <> 0 AND lv_totalpos_amt_doc    >= -1 AND lv_totalpos_amt_doc    <= 1 ) OR
                 ( lv_totalpos_amt_cocode <> 0 AND lv_totalpos_amt_cocode >= -1 AND lv_totalpos_amt_cocode <= 1 ).

*Ini --> EXT_OSCUGALD Cuenta redondeo MLA
            IF gs_header-ProviderCompanyCode EQ 'MLA' AND
               gv_proposal_type EQ zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.  "190
              FINAL(last_day) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
              DATA(round_account) = NEW zcl_interco_doc_glaccount(
                i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-exchange_difference  "RE
                i_product               = gs_header-product
                i_provider_company_code = gs_header-providercompanycode
                i_valid_at              = last_day ).

              DATA(gl_round_account) = round_account->get(
                i_recipientcompanycode = gs_header-providercompanycode ).
*          i_department = proposal_item_detail->department ).

              lv_account = |{ gl_round_account-glaccount1 ALPHA = IN }|.
            ELSE.
              lv_account = |{ ls_tvarvc_data-glaccount_redondeo ALPHA = IN }|.
            ENDIF.
*Fin --> EXT_OSCUGALD Cuenta redondeo MLA
            ls_sitecode = VALUE #( lt_sitecode[ companycode  = lv_company ] OPTIONAL ).
            lv_costcenter = ls_tvarvc_data-costcenter_redondeo.
            REPLACE ALL OCCURRENCES OF '*' IN lv_costcenter WITH ls_sitecode-internalcode.
            CONDENSE lv_costcenter.

            lv_position_num += 1.
            ls_glitems = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
                                             partnercompany      = lv_company_item
*                                             glaccount           = |{ ls_tvarvc_data-glaccount_redondeo ALPHA = IN }|
                                             GLAccount           = lv_account  "EXT_OSCUGALD Cuenta redondeo MLA
                                             documentitemtext    = lv_item_text
                                             assignmentreference = gs_header-productname
                                             material            = gs_header-product
                                             TaxCode             = tax_code
                                             _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                   THEN lv_totalpos_amt_cocode * -1
                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                   THEN lv_totalpos_amt_cocode )
                                                                              currency               = <lfs_with_item>-companycodecurrency
                                                                              exchangerate           = lv_exchangerate
                                                                              currencyrole           = '10'  )
                                                                            ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                   THEN lv_totalpos_amt_doc * -1
                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                   THEN lv_totalpos_amt_doc )
                                                                              currency               = <lfs_with_item>-documentcurrency
                                                                              exchangerate           = lv_exchangerate
                                                                              currencyrole           = '00'   ) )
                                             costcenter          =  lv_costcenter ).

            APPEND ls_glitems TO lt_glitems.
            CLEAR: ls_glitems, lv_totalpos_amt_doc, lv_totalpos_amt_cocode, lv_costcenter.

          ENDIF.

          IF lv_error = abap_false.
            "Header plus items
            APPEND INITIAL LINE TO gta_journalentry_post ASSIGNING FIELD-SYMBOL(<je_deep>).
            <je_deep>-%cid = |INT{ sy-tabix }|.
            <je_deep>-%param = VALUE #(  companycode                  = lv_company
                                         documentdate                 = <lfs_with_item>-documentdate
                                         postingdate                  = <lfs_with_item>-postingdate
                                         accountingdocumenttype       = ls_tvarvc_data-blart
                                         accountingdocumentheadertext = |{ ls_item_1-providercompanycode } { ls_item_1-recipientcompanycode  } { gs_header-productname }|
                                         createdbyuser                = cl_abap_context_info=>get_user_technical_name( )
                                        _glitems                      = lt_glitems  ).

            DATA(lo_exe_bo) = NEW zcl_proposal_bo_wt_post_par( iv_process  = zcl_boproposal_tools=>gc_create_doc
                                                               iv_doc_type = gv_proposal_type
                                                               it_doc_map  = gt_doc_map_db
                                                               it_je_post  = gta_journalentry_post ).

            APPEND lo_exe_bo TO gtd_list_bo.

          ENDIF.

          CLEAR: gt_doc_map_db, gta_journalentry_post, lt_glitems, ls_relprodrate, lv_company, lv_totalpos_amt_doc, lv_totalpos_amt_cocode,
                 lv_position_num, lv_wth_amt_cocode, lv_wth_amt_doc, lv_perc_no_comp, ls_relprodrate, lv_costcenter, lv_cc_code,
                 ls_sitecode, ls_glaccount_1, ls_glaccount_2, ls_item_dept, ls_item_1, lv_flag, lv_company_item.

        CATCH cx_sy_itab_line_not_found.
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDTRY.

    ENDLOOP.

    IF lv_error = abap_true.
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

    IF gtd_list_bo IS NOT INITIAL.
      exe_bo( ).
      et_doc_map = me->gt_doc_map_db.  "ext_oscugald
      save_log( ).
      IF gt_doc_map_db[] IS INITIAL OR
          line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
          OR line_exists( gt_doc_map_db[ status = abap_false ] ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD constructor.

    super->constructor(
      iv_doctype = iv_doctype
      is_header  = is_header
      it_items   = it_items
      its_doc    = its_doc
      it_doc     = it_doc
      it_doc_map = it_doc_map ).

    gtd_doc_bd        = it_doc.
    gv_proposal_type  = iv_proposal_type.
    gt_doc_map_si     = it_doc_map.
    gv_process        = iv_process.

  ENDMETHOD.


  METHOD preparedata.

    CLEAR: gt_doc_map_si.

    CASE gv_proposal_type.
      WHEN zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
        me->preparedata_so( ).
      WHEN zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
        me->preparedata_po( ).
      WHEN zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.    "EXT_OSCUGALD - Reclassification Grossing Up
        me->preparedata_recl( ).
      WHEN zcl_proposal_bo_abs=>c_document_type-journalentry_ic.        "EXT_OSCUGALD - DF438 Asientos contables Uruguay
        me->preparedata_uy( ).
      WHEN OTHERS.
        RETURN.
    ENDCASE.

  ENDMETHOD.


  METHOD preparedata_uy.
* EXT_OSCUGALD - DF438 Asientos contables Uruguay
    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>) .

      DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                             item_id      = <fs_items>-item_id
                                             itembasis_id = <fs_items>-itembasis_id
                                             itemcalc_id  = <fs_items>-itemcalc_id
                                             documenttype = zcl_proposal_bo_abs=>c_document_type-journalentry_ic ] OPTIONAL ).
      IF ls_doc_bd IS INITIAL.
        ls_doc_bd = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                         item_id      = <fs_items>-item_id
                                         itembasis_id = <fs_items>-itembasis_id
                                         itemcalc_id  = <fs_items>-itemcalc_id
                                         documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post ] OPTIONAL ).

        IF ls_doc_bd IS NOT INITIAL.

          IF ls_doc_bd-documentkey(5) = 'DUMMY'.
            " Doc 190 creado en esta misma ejecución: doc AR embebido tras el prefijo
            APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_doc_map_si>).
            <fs_doc_map_si>-id                = <fs_items>-id.
            <fs_doc_map_si>-item_id           = <fs_items>-item_id.
            <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
            <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
            <fs_doc_map_si>-documentkey       = ls_doc_bd-documentkey+5(10).
            <fs_doc_map_si>-documenttype      = ls_doc_bd-documenttype.
            <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
            <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
            <fs_doc_map_si>-companycode       = <fs_items>-providercompanycode.

          ELSE.
            " Doc 190 ya contabilizado → usar parentdocumentkey como clave del doc AR
            APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING <fs_doc_map_si>.
            <fs_doc_map_si>-id                = <fs_items>-id.
            <fs_doc_map_si>-item_id           = <fs_items>-item_id.
            <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
            <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
            <fs_doc_map_si>-documentkey       = ls_doc_bd-parentdocumentkey.
            <fs_doc_map_si>-documenttype      = ls_doc_bd-parentdocumenttype.
            <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
            <fs_doc_map_si>-companycode       = ls_doc_bd-companycode.

          ENDIF.

        ENDIF.

      ELSEIF ls_doc_bd-documentkey(5) = 'DUMMY'.
        " Doc 250 creado en esta misma ejecución
        APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING <fs_doc_map_si>.
        <fs_doc_map_si>-id                = <fs_items>-id.
        <fs_doc_map_si>-item_id           = <fs_items>-item_id.
        <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
        <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
        <fs_doc_map_si>-documentkey       = ls_doc_bd-documentkey+5(10).
        <fs_doc_map_si>-documenttype      = ls_doc_bd-documenttype.
        <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
        <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
        <fs_doc_map_si>-companycode       = <fs_items>-providercompanycode.

      ENDIF.

      CLEAR ls_doc_bd.

    ENDLOOP.

    DELETE gt_doc_map_si WHERE documenttype <> zcl_proposal_bo_abs=>c_document_type-journalentry_ic
                           AND documenttype <> zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                           AND documenttype <> zcl_proposal_bo_abs=>c_document_type-je_sales.
* EXT_OSCUGALD - DF438 Asientos contables Uruguay
  ENDMETHOD.


  METHOD preparedata_recl.
* ext_oscugald - Reclassification Grossing Up
    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>).

      DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                             item_id      = <fs_items>-item_id
                                             itembasis_id = <fs_items>-itembasis_id
                                             itemcalc_id  = <fs_items>-itemcalc_id
                                             documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif ] OPTIONAL ).
      IF ls_doc_bd IS INITIAL.
        ls_doc_bd = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                         item_id      = <fs_items>-item_id
                                         itembasis_id = <fs_items>-itembasis_id
                                         itemcalc_id  = <fs_items>-itemcalc_id
                                         documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post ] OPTIONAL ).
        IF ls_doc_bd IS NOT INITIAL.
          APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_doc_map_si>).
          <fs_doc_map_si>-id            = <fs_items>-id.
          <fs_doc_map_si>-item_id       = <fs_items>-item_id.
          <fs_doc_map_si>-itembasis_id  = <fs_items>-itembasis_id.
          <fs_doc_map_si>-itemcalc_id   = <fs_items>-itemcalc_id.
          <fs_doc_map_si>-documentkey   = ls_doc_bd-documentkey.
          <fs_doc_map_si>-documenttype  = ls_doc_bd-documenttype.
          <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
          <fs_doc_map_si>-fiscalyear    = ls_doc_bd-fiscalyear.
          <fs_doc_map_si>-companycode   = ls_doc_bd-companycode.
          <fs_doc_map_si>-accountingdocumenttype = ls_doc_bd-accountingdocumenttype.
        ENDIF.
      ELSEIF ls_doc_bd-documentkey(5) = 'DUMMY'.
        APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING <fs_doc_map_si>.
        <fs_doc_map_si>-id                = <fs_items>-id.
        <fs_doc_map_si>-item_id           = <fs_items>-item_id.
        <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
        <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
        <fs_doc_map_si>-documentkey       = ls_doc_bd-documentkey+5(10).
        <fs_doc_map_si>-documenttype      = ls_doc_bd-documenttype.
        <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
        <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
        <fs_doc_map_si>-companycode       = <fs_items>-recipientcompanycode.
      ENDIF.

      CLEAR ls_doc_bd.

    ENDLOOP.

    DELETE gt_doc_map_si WHERE documenttype <> zcl_proposal_bo_abs=>c_document_type-grossingupreclassif AND
                               documenttype <> zcl_proposal_bo_abs=>c_document_type-si_withholding_post.

  ENDMETHOD.


  METHOD preparedata_po.

    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>).

      DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                             item_id      = <fs_items>-item_id
                                             itembasis_id = <fs_items>-itembasis_id
                                             itemcalc_id  = <fs_items>-itemcalc_id
                                             documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post ] OPTIONAL ).
      IF ls_doc_bd IS INITIAL.
        ls_doc_bd = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                         item_id      = <fs_items>-item_id
                                         itembasis_id = <fs_items>-itembasis_id
                                         itemcalc_id  = <fs_items>-itemcalc_id
                                         documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase ] OPTIONAL ).
        IF ls_doc_bd IS NOT INITIAL.
          APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_doc_map_si>).
          <fs_doc_map_si>-id            = <fs_items>-id.
          <fs_doc_map_si>-item_id       = <fs_items>-item_id.
          <fs_doc_map_si>-itembasis_id  = <fs_items>-itembasis_id.
          <fs_doc_map_si>-itemcalc_id   = <fs_items>-itemcalc_id.
          <fs_doc_map_si>-documentkey   = ls_doc_bd-documentkey.
          <fs_doc_map_si>-documenttype  = ls_doc_bd-documenttype.
          <fs_doc_map_si>-fiscalyear    = ls_doc_bd-fiscalyear.
          <fs_doc_map_si>-companycode   = ls_doc_bd-companycode.
        ENDIF.
      ELSEIF ls_doc_bd-documentkey(5) = 'DUMMY'.
        APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING <fs_doc_map_si>.
        <fs_doc_map_si>-id                = <fs_items>-id.
        <fs_doc_map_si>-item_id           = <fs_items>-item_id.
        <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
        <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
        <fs_doc_map_si>-documentkey       = ls_doc_bd-documentkey+5(10).
        <fs_doc_map_si>-documenttype      = ls_doc_bd-documenttype.
        <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
        <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
        <fs_doc_map_si>-companycode       = <fs_items>-recipientcompanycode.
      ENDIF.

      CLEAR ls_doc_bd.

    ENDLOOP.

    DELETE gt_doc_map_si WHERE documenttype <> zcl_proposal_bo_abs=>c_document_type-si_withholding_post AND
                               documenttype <> zcl_proposal_bo_abs=>c_document_type-je_purchase.

  ENDMETHOD.


  METHOD preparedata_so.

    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>) .

      DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                             item_id      = <fs_items>-item_id
                                             itembasis_id = <fs_items>-itembasis_id
                                             itemcalc_id  = <fs_items>-itemcalc_id
                                             documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post ] OPTIONAL ).
      IF ls_doc_bd IS INITIAL.
        ls_doc_bd = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                         item_id      = <fs_items>-item_id
                                         itembasis_id = <fs_items>-itembasis_id
                                         itemcalc_id  = <fs_items>-itemcalc_id
                                         documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales ] OPTIONAL ).
        IF ls_doc_bd IS NOT INITIAL.
          APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING FIELD-SYMBOL(<fs_doc_map_si>).
          <fs_doc_map_si>-id             = <fs_items>-id.
          <fs_doc_map_si>-item_id        = <fs_items>-item_id.
          <fs_doc_map_si>-itembasis_id   = <fs_items>-itembasis_id.
          <fs_doc_map_si>-itemcalc_id    = <fs_items>-itemcalc_id.
          <fs_doc_map_si>-documentkey    = ls_doc_bd-documentkey.
          <fs_doc_map_si>-documenttype   = ls_doc_bd-documenttype.
          <fs_doc_map_si>-fiscalyear     = ls_doc_bd-fiscalyear.
          <fs_doc_map_si>-companycode    = ls_doc_bd-companycode.
        ENDIF.
      ELSEIF ls_doc_bd-documentkey(5) = 'DUMMY'.
        APPEND INITIAL LINE TO gt_doc_map_si ASSIGNING <fs_doc_map_si>.
        <fs_doc_map_si>-id                = <fs_items>-id.
        <fs_doc_map_si>-item_id           = <fs_items>-item_id.
        <fs_doc_map_si>-itembasis_id      = <fs_items>-itembasis_id.
        <fs_doc_map_si>-itemcalc_id       = <fs_items>-itemcalc_id.
        <fs_doc_map_si>-documentkey       = ls_doc_bd-documentkey+5(10).
        <fs_doc_map_si>-documenttype      = ls_doc_bd-documenttype.
        <fs_doc_map_si>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
        <fs_doc_map_si>-fiscalyear        = ls_doc_bd-fiscalyear.
        <fs_doc_map_si>-companycode       = <fs_items>-providercompanycode.
      ENDIF.

      CLEAR ls_doc_bd.

    ENDLOOP.

    DELETE gt_doc_map_si WHERE documenttype <> zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                           AND documenttype <> zcl_proposal_bo_abs=>c_document_type-je_sales.

  ENDMETHOD.


  METHOD preparedata_reverse.

    CASE gv_proposal_type.
      WHEN zcl_proposal_bo_abs=>c_document_type-anul_si_withholding.

        LOOP AT gtd_doc_bd ASSIGNING FIELD-SYMBOL(<fs_items_si>).

          IF <fs_items_si>-documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.

            DATA(ls_doc_si) = VALUE #( gtd_doc_bd[ id                = <fs_items_si>-id
                                                   parentdocumentkey = <fs_items_si>-documentkey
                                                   companycode       = <fs_items_si>-companycode
                                                   documenttype      = zcl_proposal_bo_abs=>c_document_type-anul_si_withholding ] OPTIONAL ).

            IF ls_doc_si IS INITIAL OR ls_doc_si-documentkey(5) = 'DUMMY'.
              APPEND <fs_items_si> TO gt_doc_map_si.
            ENDIF.

          ENDIF.

        ENDLOOP.

      WHEN zcl_proposal_bo_abs=>c_document_type-anul_bd_withholding.

        LOOP AT gtd_doc_bd ASSIGNING FIELD-SYMBOL(<fs_items_bd>).

          IF <fs_items_bd>-documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.

            DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id                = <fs_items_bd>-id
                                                   parentdocumentkey = <fs_items_bd>-documentkey
                                                   companycode       = <fs_items_bd>-companycode
                                                   documenttype      = zcl_proposal_bo_abs=>c_document_type-anul_bd_withholding ] OPTIONAL ).

            IF ls_doc_bd IS INITIAL OR ls_doc_bd-documentkey(5) = 'DUMMY'.
              APPEND <fs_items_bd> TO gt_doc_map_si.
            ENDIF.

          ENDIF.

        ENDLOOP.

* EXT_OSCUGALD - Reclasificación Grossing Up Prestataria
      WHEN zcl_proposal_bo_abs=>c_document_type-anul_grossingup_reclassif.

        LOOP AT gtd_doc_bd ASSIGNING FIELD-SYMBOL(<fs_items_recl>).

          IF <fs_items_recl>-documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.

            DATA(ls_doc_recl) = VALUE #( gtd_doc_bd[ id                = <fs_items_recl>-id
                                                   parentdocumentkey = <fs_items_recl>-documentkey
                                                   companycode       = <fs_items_recl>-companycode
                                                   documenttype      = zcl_proposal_bo_abs=>c_document_type-anul_grossingup_reclassif ] OPTIONAL ).

*Ini EXT_OSCUGALD 2026-08-26 - Fix reanulacion Grossing Up (SDFPSINIC-23362)
*   Mismo bug de copy-paste que en Uruguay: evaluaba ls_doc_bd en vez de
*   ls_doc_recl, impidiendo el reintento correcto de anulacion 230.
            IF ls_doc_recl IS INITIAL OR ls_doc_recl-documentkey(5) = 'DUMMY'.
*Fin EXT_OSCUGALD 2026-08-26 - Fix reanulacion Grossing Up (SDFPSINIC-23362)

              APPEND <fs_items_recl> TO gt_doc_map_si.

            ENDIF.
          ENDIF.
        ENDLOOP.
* EXT_OSCUGALD - Reclasificacion Grossing Up Prestataria

*Ini EXT_OSCUGALD 2026-08-26 - Fix WHEN faltante Uruguay (SDFPSINIC-23362)
*   El bloque de Uruguay estaba anidado dentro del WHEN de Grossing Up
*   (sin su propio WHEN), por lo que cuando gv_proposal_type = 260
*   (anul_journalentry_ic) el CASE nunca entraba a este bloque y caia
*   directo en WHEN OTHERS -> RETURN. Por eso nunca se generaba ni error
*   ni documento de anulacion 260: el metodo nunca llegaba a intentarlo.
      WHEN zcl_proposal_bo_abs=>c_document_type-anul_journalentry_ic.
*Fin EXT_OSCUGALD 2026-08-26 - Fix WHEN faltante Uruguay (SDFPSINIC-23362)
* EXT_OSCUGALD - DF438 Asientos contables Uruguay

        LOOP AT gtd_doc_bd ASSIGNING FIELD-SYMBOL(<fs_items_uy>).

          IF <fs_items_uy>-documenttype = zcl_proposal_bo_abs=>c_document_type-journalentry_ic.

            DATA(ls_doc_uy) = VALUE #( gtd_doc_bd[ id                = <fs_items_uy>-id
                                                   parentdocumentkey = <fs_items_uy>-documentkey
                                                   companycode       = <fs_items_uy>-companycode
                                                   documenttype      = zcl_proposal_bo_abs=>c_document_type-anul_journalentry_ic ] OPTIONAL ).

*Ini EXT_OSCUGALD 2026-08-26 - Fix reanulacion Uruguay (SDFPSINIC-23362)
*   METHOD preparedata_reverse: bug de copy-paste. La condicion evaluaba
*   ls_doc_bd (variable del ramal anterior Grossing Up, linea ~2340) en vez
*   de ls_doc_uy (la propia de este ramal Uruguay/260). Esto impedia que el
*   reintento de reanulacion detectara el registro dummy 260 en error,
*   dejando CPD sin actualizar (isdeleted vacio, status E) y CPDL
*   acumulando mensajes repetidos en cada reanulacion.
            IF ls_doc_uy IS INITIAL OR ls_doc_uy-documentkey(5) = 'DUMMY'.
*Fin EXT_OSCUGALD 2026-08-26 - Fix reanulacion Uruguay (SDFPSINIC-23362)

              APPEND <fs_items_uy> TO gt_doc_map_si.

            ENDIF.
          ENDIF.
        ENDLOOP.
* EXT_OSCUGALD - DF438 Asientos contables Uruguay
      WHEN OTHERS.
        RETURN.
    ENDCASE.

  ENDMETHOD.


  METHOD get_tvarvc.

    DATA lv_low TYPE zi_tvarvc-low.

    SELECT name,
           sign,
           opti,
           low,
           high
    FROM zi_tvarvc
    WHERE name = @gc_doctype             OR
          name = @gc_tarifftype_item_1   OR
          name = @gc_tarifftype_item_2n  OR
          name = @gc_glaccount_redondeo  OR
          name = @gc_costcenter_redondeo OR
          name = @gc_blart               OR
          name = @gc_glaccount_item_1    OR  "DF438 Asientos contables Uruguay
          name = @gc_glaccount_item_2n   OR  "DF438 Asientos contables Uruguay
          name = @gc_glaccount_je        ORDER BY name
    INTO TABLE @DATA(lt_tvarvc).
    IF sy-subrc = 0.

*EXT_OSCUGALD - DF438 Asientos contables Uruguay - Carga de cuentas contables por tipo de propuesta
      TRY.
          DATA(ls_tvarvc) = lt_tvarvc[ name = gc_glaccount_item_1  ] .
          iv_tvarvc_data-glaccount_item_1 = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_glaccount_item_2n  ].
          iv_tvarvc_data-glaccount_item_2n = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
*EXT_OSCUGALD - DF438 Asientos contables Uruguay - Carga de cuentas contables por tipo de propuesta

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_tarifftype_item_1  ] .
          iv_tvarvc_data-tarifftype_item_1 = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_tarifftype_item_2n  ].
          iv_tvarvc_data-tarifftype_item_2n = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_glaccount_redondeo  ].
          iv_tvarvc_data-glaccount_redondeo = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_costcenter_redondeo ].
          iv_tvarvc_data-costcenter_redondeo = ls_tvarvc-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      lv_low = gv_proposal_type.
      CONDENSE lv_low.

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_doctype low = lv_low ].
          iv_tvarvc_data-doctype = ls_tvarvc-high.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      TRY.
          ls_tvarvc = lt_tvarvc[ name = gc_blart low = lv_low ].
          iv_tvarvc_data-blart = ls_tvarvc-high.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      iv_tvarvc_data-glaccount_je = VALUE #( FOR ls_tvarvc_value IN lt_tvarvc WHERE ( name = gc_glaccount_je )
                                                                 ( sign   = ls_tvarvc_value-sign
                                                                   option = ls_tvarvc_value-opti
                                                                   low    = ls_tvarvc_value-low
                                                                   high   = ls_tvarvc_value-high ) ).

    ENDIF.

  ENDMETHOD.


  METHOD map_error.

    DATA: lt_doc_map_log TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
          lt_doc_map_db  TYPE gtty_doc,
          lv_status_log  TYPE zfi_a_intrc_cpdl-msgty,
          lv_attime      TYPE zfi_a_intrc_cpid-createdat,
          lv_byuser      TYPE zfi_a_intrc_cpid-createdby.

    lt_doc_map_log = VALUE #( ( %msg = new_message( id       = iv_id
                                                    number   = iv_number
                                                    severity = iv_severity
                                                    v1       = iv_doc_map-documentkey ) ) ).

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    mapping_doc_log( EXPORTING iv_dockey      = iv_doc_key
                               iv_companycode = iv_doc_map-companycode
                               iv_fiscalyear  = iv_doc_map-fiscalyear
                               iv_doctype     = gv_proposal_type
                               it_reported    = lt_doc_map_log
                     CHANGING  ct_map_id_doc  = gt_doc_map_si
                               cv_status      = lv_status_log ).

    APPEND INITIAL LINE TO lt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map_log>).
    <fs_doc_map_log>-id             = iv_doc_map-id.
    <fs_doc_map_log>-item_id        = iv_doc_map-item_id.
    <fs_doc_map_log>-itembasis_id   = iv_doc_map-itembasis_id.
    <fs_doc_map_log>-itemcalc_id    = iv_doc_map-itemcalc_id.
    <fs_doc_map_log>-documentkey    = iv_doc_key.

    mapping_doc( EXPORTING iv_dockey        = iv_doc_key
                           iv_companycode   = iv_doc_map-companycode
                           iv_fiscalyear    = iv_doc_map-fiscalyear
                           iv_parentdockey  = iv_doc_map-documentkey
                           iv_parentdoctype = iv_doc_map-documenttype
                           iv_doctype       = gv_proposal_type
                           iv_status        = me->c_document_status-error
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_isadjustment  = space
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = lt_doc_map_db ).

  ENDMETHOD.


  METHOD get_percent_of_total.

    DATA: ls_total_item       TYPE gty_total_item,
          lt_total_item       TYPE gtty_total_item,
          ls_item_sum         TYPE gty_item_sum,
          lv_dif              TYPE gty_item_sum-percentoftotal,
          lv_total_aux        TYPE gty_item_sum-percentoftotal,
          lv_profitcenter_aux TYPE zi_intercoproposalitem-profitcenter.

    IF gtd_items_add IS INITIAL.
      RETURN.
    ENDIF.

*Ini EXT_OSCUGALD 18.02.2026 - Genova MLA
    " 1. Carga de constantes TVARVC (Filtros Genova)
    SELECT name, low FROM zi_tvarvc
      WHERE name IN ('Z_GENOVA_PROVIDER', 'Z_GENOVA_PRODUCT', 'Z_GENOVA_HIER')
      INTO TABLE @DATA(lt_constants).
*Fin EXT_OSCUGALD 18.02.2026 - Genova MLA
    SELECT zi_intercoproposalitemorglacct~id,
           zi_intercoproposalitemorglacct~itemid,
           zi_intercoproposalitemorglacct~department,
           zi_intercoproposalitemorglacct~costcenter,
           zi_intercoproposalitemorglacct~costcenterd4,
           zi_intercoproposalitemorglacct~cebe_aux,               "Genova MLA
           zi_intercoproposalitemorglacct~costcenterstdhierarea,  "Genova MLA
           zi_intercoproposalitemorglacct~\_item-profitcenter,
           zi_intercoproposalitemorglacct~\_item-profitcentereq,
           zi_intercoproposalitemorglacct~amountinglobalcurrency,
           zi_intercoproposalitemorglacct~\_item-providercountry,
           zi_intercoproposalitemorglacct~\_item-recipientcountry
    FROM  zi_intercoproposalitemorglacct
    INNER JOIN @gtd_items_add AS items
    ON    zi_intercoproposalitemorglacct~id      = items~id
    AND   zi_intercoproposalitemorglacct~itemid  = items~item_id
    INTO TABLE @DATA(lt_itemorglacct).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "Se reeplaza item con profitcenter eq por correpondiente donde profitcenter  = profitcentereq
    LOOP AT lt_itemorglacct ASSIGNING FIELD-SYMBOL(<lfs_item>).
      IF <lfs_item>-cebe_aux = '200' AND
         line_exists( lt_constants[ name = 'Z_GENOVA_PROVIDER' low = gs_header-providercompanycode ] ) AND
         line_exists( lt_constants[ name = 'Z_GENOVA_PRODUCT'  low = gs_header-Product ] ) AND
         line_exists( lt_constants[ name = 'Z_GENOVA_HIER'     low = 'IT0722' ] ).
        <lfs_item>-CostCenterStdHierArea = 'IT0722'.
        <lfs_item>-CostCenterD4 = <lfs_item>-CostCenter+4(1).
      ENDIF.
      IF <lfs_item>-profitcentereq IS NOT INITIAL.

        lv_profitcenter_aux = |{ <lfs_item>-profitcentereq ALPHA = IN }|.

        TRY.
            DATA(ls_aux) = lt_itemorglacct[ profitcenter      = lv_profitcenter_aux
                                            recipientcountry  = <lfs_item>-recipientcountry ].

          CATCH cx_sy_itab_line_not_found.

**** INICIO  CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10
            <lfs_item>-profitcenter = <lfs_item>-profitcentereq.
            <lfs_item>-profitcenter  = |{ <lfs_item>-profitcenter ALPHA = IN  }|.
**** INICIO  CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10
            CONTINUE.
        ENDTRY.

        <lfs_item>-profitcenter  = lv_profitcenter_aux.
        <lfs_item>-itemid        = ls_aux-itemid.

        CLEAR: <lfs_item>-profitcentereq.
        CLEAR: lv_profitcenter_aux.

      ENDIF.

      "Se excluyen los registros de CECOS LOCALES.
      IF <lfs_item>-providercountry <> <lfs_item>-recipientcountry AND <lfs_item>-costcenterd4 = 0.
        DELETE lt_itemorglacct INDEX sy-tabix.
      ENDIF.

    ENDLOOP.

    "Se excluyen los registros HISPANOS/BRAZIL
    DELETE lt_itemorglacct WHERE providercountry <> 'BR' AND recipientcountry = 'BR' AND costcenterd4 = 3.

*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1: profitcenter en GROUP BY del total
*   IMPORTANTE: el total se agrupa por (id, itemid, profitcenter) SIN costcenterd4.
*   Razon: percent_je no distingue d4 — es un unico porcentaje por PC sobre el
*   doc AR completo. Si el denominador de percentoftotal fuera por (d4, PC), la
*   suma de percentoftotal para d4=1 + d4=3 del mismo PC daria 200%, aplicando
*   percent_je dos veces y generando un monto distribuido de solo el 57% del real.
*   Con el denominador por PC (sin d4), percentoftotal suma 100% por PC considerando
*   todos los d4 juntos — consistente con percent_je — y el producto cierra al 100%.
    SORT lt_itemorglacct BY id itemid profitcenter.

    LOOP AT lt_itemorglacct INTO DATA(ls_item) GROUP BY ( id           = ls_item-id
                                                          itemid       = ls_item-itemid
                                                          profitcenter = ls_item-profitcenter ).

      LOOP AT GROUP ls_item INTO DATA(ls_item_group).
        ls_total_item-total = ls_total_item-total + ls_item_group-amountinglobalcurrency.
      ENDLOOP.

      IF ls_total_item IS NOT INITIAL.
        ls_total_item-id           = ls_item-id.
        ls_total_item-itemid       = ls_item-itemid.
        ls_total_item-profitcenter = ls_item-profitcenter.
        APPEND ls_total_item TO lt_total_item.
        CLEAR ls_total_item.
      ENDIF.

    ENDLOOP.
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1

    SORT lt_itemorglacct BY id itemid department costcenterd4 profitcenter.

    LOOP AT lt_itemorglacct INTO DATA(ls_item_prop) GROUP BY ( id            = ls_item_prop-id
                                                               itemid        = ls_item_prop-itemid
                                                               department    = ls_item_prop-department
                                                               costcenterd4  = ls_item_prop-costcenterd4
                                                               profitcenter  = ls_item_prop-profitcenter ).
      LOOP AT GROUP ls_item_prop INTO DATA(ls_group_prop).
        ls_item_sum-id              = ls_group_prop-id.
        ls_item_sum-item_id         = ls_group_prop-itemid.
        ls_item_sum-department      = ls_group_prop-department.
        ls_item_sum-costcenterd4    = ls_group_prop-costcenterd4.
        ls_item_sum-costcenter      = ls_group_prop-costcenter.
        ls_item_sum-profitcenter    = ls_group_prop-profitcenter.
        ls_item_sum-profitcentereq  = ls_group_prop-profitcentereq.

        TRY.
*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1: profitcenter en lookup del total (sin d4)
            DATA(ls_total) = lt_total_item[ id           = ls_item_prop-id
                                            itemid       = ls_item_prop-itemid
                                            profitcenter = ls_item_prop-profitcenter ].
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1

            lv_total_aux = ( ls_group_prop-amountinglobalcurrency / ls_total-total ) * 100000.
            ls_item_sum-percentoftotal =   ls_item_sum-percentoftotal + lv_total_aux.
            CLEAR lv_total_aux.

          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.

      ENDLOOP.

      IF ls_item_sum IS NOT INITIAL.
        APPEND ls_item_sum TO ch_item_sum.
        CLEAR ls_item_sum.
      ENDIF.

    ENDLOOP.


*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1: normalizacion final por (id, itemid, PC) sin d4
*   La normalizacion agrupa por PC sin d4 para que la suma de percentoftotal
*   de todas las filas del mismo PC (con distintos d4 y departamentos) sea 100000.
*   Esto es consistente con percent_je que tampoco distingue d4.
    SORT ch_item_sum BY id item_id profitcenter percentoftotal DESCENDING.

    LOOP AT ch_item_sum ASSIGNING FIELD-SYMBOL(<lfs_aux>) GROUP BY ( id           = <lfs_aux>-id
                                                                     itemid       = <lfs_aux>-item_id
                                                                     profitcenter = <lfs_aux>-profitcenter ).
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033 Capa1

      CLEAR: lv_total_aux, lv_dif.

      LOOP AT GROUP <lfs_aux> ASSIGNING FIELD-SYMBOL(<lfs_group>).

        lv_total_aux = lv_total_aux + <lfs_group>-percentoftotal.

      ENDLOOP.

      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
      lv_dif = 100000 - lv_total_aux.
      <lfs_aux>-percentoftotal = <lfs_aux>-percentoftotal + lv_dif.

    ENDLOOP.


  ENDMETHOD.


  METHOD get_percent_je.

    DATA: ls_total_je   TYPE gty_total_je,
          lt_total_je   TYPE gtty_total_je,
          ls_percent_je TYPE gty_percent_je,
          lv_dif        TYPE gty_item_sum-percentoftotal,
          lv_total_aux  TYPE gty_item_sum-percentoftotal.

    CONSTANTS lc_profitcenter_redondeo TYPE i_journalentryitem-profitcenter VALUE '0000000999'.

    IF iv_doc_map_si IS INITIAL.
      RETURN.
    ENDIF.

    SELECT accountingdocument,
           companycode,
           fiscalyear,
           glaccount,
           profitcenter,
           amountintransactioncurrency,
           transactioncurrency,
           amountinglobalcurrency,
           globalcurrency
           FROM i_journalentryitem WITH PRIVILEGED ACCESS
    FOR ALL ENTRIES IN @iv_doc_map_si
    WHERE accountingdocument = @iv_doc_map_si-documentkey(10)
    AND   companycode        = @iv_doc_map_si-companycode
    AND   fiscalyear         = @iv_doc_map_si-fiscalyear
    AND   glaccount   IN @iv_glaccount_je
    AND   sourceledger = '0L'
    INTO TABLE @DATA(lt_je).
    IF sy-subrc = 0.

      SORT lt_je BY accountingdocument companycode fiscalyear.

      LOOP AT lt_je INTO DATA(ls_je) GROUP BY ( accountingdocument = ls_je-accountingdocument
                                                companycode        = ls_je-companycode
                                                fiscalyear         = ls_je-fiscalyear ).

        LOOP AT GROUP ls_je INTO DATA(ls_group_je).

          ls_total_je-accountingdocument          = ls_group_je-accountingdocument.
          ls_total_je-companycode                 = ls_group_je-companycode.
          ls_total_je-fiscalyear                  = ls_group_je-fiscalyear.
          ls_total_je-glaccount                   = ls_group_je-glaccount.
          ls_total_je-profitcenter                = ls_group_je-profitcenter.
          ls_total_je-amountintransactioncurrency = ls_total_je-amountintransactioncurrency + ls_group_je-amountintransactioncurrency.
          ls_total_je-transactioncurrency         = ls_group_je-transactioncurrency.
          ls_total_je-amountinglobalcurrency      = ls_total_je-amountinglobalcurrency + ls_group_je-amountinglobalcurrency.
          ls_total_je-globalcurrency              = ls_group_je-globalcurrency.

        ENDLOOP.

        IF ls_total_je IS NOT INITIAL.
          APPEND ls_total_je TO lt_total_je.
          CLEAR ls_total_je.
        ENDIF.

      ENDLOOP.

      LOOP AT lt_je INTO DATA(ls_je_aux).

        TRY.
            DATA(ls_total) = lt_total_je[ accountingdocument = ls_je_aux-accountingdocument
                                          companycode        = ls_je_aux-companycode
                                          fiscalyear         = ls_je_aux-fiscalyear ].
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.

        ls_percent_je-accountingdocument          = ls_je_aux-accountingdocument.
        ls_percent_je-companycode                 = ls_je_aux-companycode.
        ls_percent_je-fiscalyear                  = ls_je_aux-fiscalyear.
        ls_percent_je-glaccount                   = ls_je_aux-glaccount.
        ls_percent_je-profitcenter                = ls_je_aux-profitcenter.

        IF ls_total-amountinglobalcurrency <> 0.
          ls_percent_je-percent  =  ( ls_je_aux-amountinglobalcurrency / ls_total-amountinglobalcurrency ) * 100000.
        ENDIF.

        IF ls_percent_je-percent = 0.
          CONTINUE.
        ENDIF.

        APPEND ls_percent_je TO ch_percent_je.
        CLEAR ls_percent_je.

      ENDLOOP.

    ENDIF.

    SORT ch_percent_je BY accountingdocument companycode fiscalyear percent DESCENDING.

    LOOP AT ch_percent_je ASSIGNING FIELD-SYMBOL(<lfs_percent>)  GROUP BY ( accountingdocument = <lfs_percent>-accountingdocument
                                                                            companycode        = <lfs_percent>-companycode
                                                                            fiscalyear         = <lfs_percent>-fiscalyear ).

      LOOP AT GROUP <lfs_percent> ASSIGNING FIELD-SYMBOL(<lfs_group>).
        lv_total_aux = lv_total_aux + <lfs_group>-percent.
      ENDLOOP.

      DATA(ls_aux) = VALUE #( ch_percent_je[ accountingdocument = <lfs_percent>-accountingdocument
                                             companycode        = <lfs_percent>-companycode
                                             fiscalyear         = <lfs_percent>-fiscalyear
                                             profitcenter       = lc_profitcenter_redondeo ] OPTIONAL ).

      "Se suma el porcentaje de profit center de redondeo a la linea con mayor porcentaje.
      <lfs_percent>-percent =   <lfs_percent>-percent + ls_aux-percent.

      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
      lv_dif = 100000 - lv_total_aux.
      <lfs_percent>-percent = <lfs_percent>-percent + lv_dif.

      CLEAR: lv_total_aux, lv_dif, ls_aux.

    ENDLOOP.

    DELETE ch_percent_je WHERE profitcenter = lc_profitcenter_redondeo.

  ENDMETHOD.


  METHOD get_percent_his.

    DATA: ls_total_je    TYPE gty_total_je,
          lt_total_je    TYPE gtty_total_je,
          ls_percent_his TYPE gty_percent_his,
          lv_dif         TYPE gty_item_sum-percentoftotal,
          lv_total_aux   TYPE gty_item_sum-percentoftotal,
          lt_je          TYPE gtty_je_his.

    IF iv_doc_map_si IS INITIAL.
      RETURN.
    ENDIF.

    SELECT i_journalentryitem~accountingdocument,
           i_journalentryitem~companycode,
           i_journalentryitem~fiscalyear,
           i_journalentryitem~glaccount,
           i_journalentryitem~profitcenter,
           i_journalentryitem~costcenter,
           i_journalentryitem~amountintransactioncurrency,
           i_journalentryitem~transactioncurrency,
           i_journalentryitem~amountinglobalcurrency,
           i_journalentryitem~globalcurrency,
           i_journalentryitem~partnercompany,
           partner~country  AS partnercountry,
           comp~country     AS companycountry
           FROM i_journalentryitem  WITH PRIVILEGED ACCESS
           INNER JOIN i_companycode WITH PRIVILEGED ACCESS AS comp
           ON i_journalentryitem~companycode    = comp~companycode
           INNER JOIN i_companycode WITH PRIVILEGED ACCESS AS partner
           ON i_journalentryitem~partnercompany = partner~companycode
           FOR ALL ENTRIES IN @iv_doc_map_si
           WHERE i_journalentryitem~accountingdocument = @iv_doc_map_si-documentkey(10)
           AND   i_journalentryitem~companycode        = @iv_doc_map_si-companycode
           AND   i_journalentryitem~fiscalyear         = @iv_doc_map_si-fiscalyear
*           AND   offsettingaccounttype = 'D'
           AND   sourceledger = '0L'
           AND   ( glaccounttype = 'P' OR glaccounttype = 'N' )
          INTO CORRESPONDING FIELDS OF TABLE @lt_je.

    IF sy-subrc = 0.

      SORT lt_je BY accountingdocument companycode fiscalyear profitcenter.

      LOOP AT lt_je  ASSIGNING FIELD-SYMBOL(<lfs_je>) GROUP BY ( accountingdocument = <lfs_je>-accountingdocument
                                                                 companycode        = <lfs_je>-companycode
                                                                 fiscalyear         = <lfs_je>-fiscalyear
                                                                 profitcenter       = <lfs_je>-profitcenter ).

        LOOP AT GROUP <lfs_je> ASSIGNING FIELD-SYMBOL(<lfs_group>).

          IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.

            IF <lfs_group>-partnercountry <> <lfs_group>-companycountry AND <lfs_group>-costcenter+3(1) = 0.
              <lfs_group>-costcenterd4 = 1.
            ELSE.
              <lfs_group>-costcenterd4 = <lfs_group>-costcenter+3(1).
            ENDIF.

          ELSE.
            <lfs_group>-costcenterd4 = <lfs_group>-costcenter+3(1).
          ENDIF.

          ls_total_je-accountingdocument          = <lfs_group>-accountingdocument.
          ls_total_je-companycode                 = <lfs_group>-companycode.
          ls_total_je-fiscalyear                  = <lfs_group>-fiscalyear.
          ls_total_je-glaccount                   = <lfs_group>-glaccount.
          ls_total_je-profitcenter                = <lfs_group>-profitcenter.
          ls_total_je-amountintransactioncurrency = ls_total_je-amountintransactioncurrency + <lfs_group>-amountintransactioncurrency.
          ls_total_je-transactioncurrency         = <lfs_group>-transactioncurrency.
          ls_total_je-amountinglobalcurrency      = ls_total_je-amountinglobalcurrency + <lfs_group>-amountinglobalcurrency.
          ls_total_je-globalcurrency              = <lfs_group>-globalcurrency.

        ENDLOOP.

        IF ls_total_je IS NOT INITIAL.
          APPEND ls_total_je TO lt_total_je.
          CLEAR ls_total_je.
        ENDIF.

      ENDLOOP.

      SORT lt_je BY accountingdocument companycode fiscalyear profitcenter costcenterd4.

      LOOP AT lt_je INTO DATA(ls_je_aux) GROUP BY ( accountingdocument = ls_je_aux-accountingdocument
                                                    companycode        = ls_je_aux-companycode
                                                    fiscalyear         = ls_je_aux-fiscalyear
                                                    profitcenter       = ls_je_aux-profitcenter
                                                    costcenterd4       = ls_je_aux-costcenterd4 ).

        LOOP AT GROUP ls_je_aux INTO DATA(ls_group_aux).

          TRY.
              DATA(ls_total) = lt_total_je[ accountingdocument = ls_group_aux-accountingdocument
                                            companycode        = ls_group_aux-companycode
                                            fiscalyear         = ls_group_aux-fiscalyear
                                            profitcenter       = ls_group_aux-profitcenter  ].
            CATCH cx_sy_itab_line_not_found.
              CONTINUE.
          ENDTRY.

          ls_percent_his-accountingdocument          = ls_group_aux-accountingdocument.
          ls_percent_his-companycode                 = ls_group_aux-companycode.
          ls_percent_his-fiscalyear                  = ls_group_aux-fiscalyear.
          ls_percent_his-glaccount                   = ls_group_aux-glaccount.
          ls_percent_his-profitcenter                = ls_group_aux-profitcenter.
          ls_percent_his-costcenterd4                = ls_group_aux-costcenterd4.

          IF ls_total-amountinglobalcurrency <> 0.
            ls_percent_his-percent  =  ls_percent_his-percent + ( ls_group_aux-amountinglobalcurrency / ls_total-amountinglobalcurrency ) * 100000.
          ENDIF.

        ENDLOOP.

        IF ls_percent_his IS NOT INITIAL.
          APPEND ls_percent_his TO ch_percent_his.
          CLEAR ls_percent_his.
        ENDIF.

      ENDLOOP.

    ENDIF.


    SORT ch_percent_his BY accountingdocument companycode profitcenter costcenterd4 fiscalyear percent DESCENDING.

    LOOP AT ch_percent_his ASSIGNING FIELD-SYMBOL(<lfs_percent>)  GROUP BY ( accountingdocument = <lfs_percent>-accountingdocument
                                                                             companycode        = <lfs_percent>-companycode
                                                                             fiscalyear         = <lfs_percent>-fiscalyear
                                                                             profitcenter       = <lfs_percent>-profitcenter ).
      " costcenterd4       = <lfs_percent>-costcenterd4

      LOOP AT GROUP <lfs_percent> ASSIGNING FIELD-SYMBOL(<lfs_group_p>).
        lv_total_aux = lv_total_aux + <lfs_group_p>-percent.
      ENDLOOP.

      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
      lv_dif = 100000 - lv_total_aux.
      <lfs_percent>-percent = <lfs_percent>-percent + lv_dif.

      CLEAR: lv_total_aux.

    ENDLOOP.

  ENDMETHOD.


  METHOD grossingup_reclassif.

    TYPES: lsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           lsty_glitems TYPE LINE OF lsty_post-%param-_glitems.

    DATA:
      lt_doc_map_log  TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
      lt_itemorglacct TYPE tt_itemorglacct,
*      lv_totalpos_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency,
*      lv_totalpos_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
      lv_amt_doc      TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_max      TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_cocode   TYPE i_journalentryitem-amountincompanycodecurrency,
*      lv_ali_grossup         TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
      lv_ali_grossup  TYPE p LENGTH 7 DECIMALS 6,
*      lv_perc_wth            TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
      lv_perc_wth     TYPE p LENGTH 7 DECIMALS 6,
      lv_part_to_wth  TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent,
*      lv_costcenter          TYPE zi_intercoproposalitemorglacct-costcenter,
      lv_doc_key      TYPE zfi_a_intrc_cpd-documentkey,
*      lv_company_item        TYPE i_journalentry-companycode,
      lt_glitems      TYPE lsty_post-%param-_glitems,
      lv_status_log   TYPE zfi_a_intrc_cpdl-msgty,
*      lv_perc_no_comp        TYPE zi_intercocompanyrelprodrate-taxcredit,
*      lt_item_sum     TYPE gtty_item_sum,
*      lv_cc_code             TYPE zde_cc_code,
      lv_error        TYPE abap_bool,
      lv_cid          TYPE abp_behv_cid,
      lv_firstday     TYPE datum,
*      lv_position_num        TYPE int4,
*      lv_item_text           TYPE sgtxt,
*      ls_tvarvc_data         TYPE gty_tvarvc_data,
      lt_percent_je   TYPE gtty_percent_je,
      lt_percent_his  TYPE gtty_percent_his,
      lv_tabix        TYPE sy-tabix,
      lv_index_mayor  TYPE sy-tabix.

    DATA: lr_glaccounts TYPE RANGE OF I_JournalEntryItem-GLAccount.

    lv_firstday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01|.
    TRY.
        DATA(lv_lastday) = zcl_interco_utils=>rp_last_day_of_months(
          EXPORTING
            day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
      CATCH cx_sy_conversion_no_date INTO DATA(exc).
        lv_lastday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod }31|.
    ENDTRY.

    IF gt_doc_map_si IS NOT INITIAL.

      SELECT validfrom,
             validto,
             doctype,
             providercompanycode,
             recipientcompanycode,
             product,
             department,
             pandlid,
             tarifftype,
             operationtype,
             glaccount1,
             glaccount2
        FROM zi_intercoglacctdetermination
        WHERE validfrom <= @lv_lastday
          AND validto >= @lv_lastday
          AND providercompanycode = @gs_header-providercompanycode
          AND doctype = 'PP'
          AND product = @gs_header-product
          AND isdeleted IS INITIAL
                INTO TABLE @DATA(lt_account).

      LOOP AT lt_account INTO DATA(ls_account).
        IF ls_account-glaccount1 IS NOT INITIAL.
          APPEND VALUE #( sign   = 'I'
                          option = 'EQ'
                          low    = ls_account-glaccount1 ) TO lr_glaccounts.
        ENDIF.
      ENDLOOP.
      SORT lr_glaccounts BY low.
      DELETE ADJACENT DUPLICATES FROM lr_glaccounts.
*    ENDIF.

      SELECT header~CompanyCode,
             header~FiscalYear,
             header~AccountingDocument,
             header~DocumentDate,
             header~PostingDate,
             header~DocumentReferenceID,
             header~exchangerate,
             item~ledger,
             item~referencedocumentitem,
             item~glaccount,
             item~costcenter,
             item~profitcenter,
             item~amountintransactioncurrency,
             item~amountincompanycodecurrency,
             item~companycodecurrency,
             item~transactioncurrency,
             item~amountinglobalcurrency,
             item~globalcurrency,
             item~sourceledger
             FROM I_JournalEntry WITH PRIVILEGED ACCESS AS header
             INNER JOIN I_JournalEntryItem WITH PRIVILEGED ACCESS AS item
               ON header~CompanyCode        = item~CompanyCode
              AND header~FiscalYear         = item~FiscalYear
              AND header~AccountingDocument = item~AccountingDocument
          FOR ALL ENTRIES IN @gt_doc_map_si
          WHERE header~CompanyCode = @gt_doc_map_si-CompanyCode
            AND header~AccountingDocument = @gt_doc_map_si-documentkey(10)
            AND header~FiscalYear = @gt_doc_map_si-fiscalyear
*          AND item~sourceledger = '0L'
            AND item~ledger = '0L'
            AND item~referencedocumentitem > 1
            AND item~glaccount IN @lr_glaccounts
          INTO TABLE @DATA(lt_JournalEntryItem).

**********************************************************************
      SORT gt_doc_map_si BY documentkey.
      SORT gtd_items_add BY id item_id itembasis_id itemcalc_id.
      SORT lt_JournalEntryItem BY AccountingDocument referencedocumentitem.
*    DELETE ADJACENT DUPLICATES FROM lt_JournalEntryItem.

      "Lectura de la cuenta de posiciones a reclasificar
      READ TABLE lt_account INTO ls_account WITH KEY DocType = 'PP'
                                                     Product = gs_header-Product
                                                     ProviderCompanyCode = gs_header-providercompanycode
                                                     TariffType = '91'.
      DATA(lv_glaccount) =  ls_account-GlAccount1.



    ENDIF.

    LOOP AT gt_doc_map_si INTO DATA(ls_doc_map) GROUP BY ls_doc_map-documentkey.
      TRY.
          " 1. Generar los ítems del asiento (Lógica global del documento)
          CALL METHOD me->journalentryitem
            EXPORTING
              it_journalentryitem = lt_JournalEntryItem
              is_doc_map          = ls_doc_map
              it_doc_account      = lt_account
              iv_glaccount1       = lv_glaccount
              it_itemorglacct     = lt_itemorglacct
            IMPORTING
              et_glitems          = lt_glitems.

          " 2. Llena tabla de mapeo (gt_doc_map_db)
          LOOP AT GROUP ls_doc_map INTO DATA(ls_member).
            DATA(ls_item_1) = gtd_items_add[ id           = ls_member-id
                                             item_id      = ls_member-item_id
                                             itembasis_id = ls_member-itembasis_id
                                             itemcalc_id  = ls_member-itemcalc_id ] .
            APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
            <fs_doc_map>-id                 = ls_member-id.
            <fs_doc_map>-item_id            = ls_member-item_id.
            <fs_doc_map>-itembasis_id       = ls_member-itembasis_id.
            <fs_doc_map>-itemcalc_id        = ls_member-itemcalc_id.
            <fs_doc_map>-documentkey        = |DUMMY{ ls_member-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
            <fs_doc_map>-parentdocumentkey  = ls_member-documentkey(10).
            <fs_doc_map>-fiscalyear         = ls_member-fiscalyear.
            <fs_doc_map>-companycode        = ls_member-companycode.
            <fs_doc_map>-documenttype       = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.
            <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
          ENDLOOP.

          " 3. Prepara cabecera del documento (Una sola vez por grupo)
          READ TABLE lt_JournalEntryItem INTO DATA(ls_JournalEntryItem) WITH KEY AccountingDocument = ls_doc_map-documentkey.

          "Header plus items
          APPEND INITIAL LINE TO gta_journalentry_post ASSIGNING FIELD-SYMBOL(<je_deep>).
          <je_deep>-%cid = |INT{ sy-tabix }|.
          <je_deep>-%param = VALUE #(  companycode                  = ls_item_1-recipientcompanycode
                                       documentdate                 = ls_JournalEntryItem-documentdate
                                       postingdate                  = ls_JournalEntryItem-postingdate
                                       accountingdocumenttype       = 'CH'
                                       accountingdocumentheadertext = |{ ls_item_1-providercompanycode } { ls_item_1-recipientcompanycode  } { gs_header-productname }|
                                       createdbyuser                = cl_abap_context_info=>get_user_technical_name( )
                                       LedgerGroup                  = 'INUS'
                                      _glitems                      = lt_glitems  ).

          DATA(lo_exe_bo) = NEW zcl_proposal_bo_wt_post_par( iv_process  = zcl_boproposal_tools=>gc_create_doc
                                                             iv_doc_type = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif
                                                             it_doc_map  = gt_doc_map_db
                                                             it_je_post  = gta_journalentry_post ).
          " 4. Agrega a la cola de ejecución
          APPEND lo_exe_bo TO gtd_list_bo.

          CLEAR: gt_doc_map_db, gta_journalentry_post, lt_glitems, ls_item_1.

        CATCH cx_sy_itab_line_not_found.
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDTRY.
    ENDLOOP.

    IF gtd_list_bo IS NOT INITIAL.
      exe_bo( ).
      save_log( ).
      IF gt_doc_map_db[] IS INITIAL OR
          line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
          OR line_exists( gt_doc_map_db[ status = abap_false ] ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD journalentryitem.

    TYPES: lsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           lsty_glitems TYPE LINE OF lsty_post-%param-_glitems.
    DATA: lv_item_text    TYPE sgtxt,
          lv_position_num TYPE int4,
          lt_glitems      TYPE lsty_post-%param-_glitems,
          lt_item_sum     TYPE gtty_item_sum.

*    me->get_percent_of_total( CHANGING ch_item_sum = lt_item_sum ).

    LOOP AT it_journalentryitem INTO DATA(ls_JournalEntryItem)
               WHERE companycode        = is_doc_map-companycode
                 AND fiscalyear         = is_doc_map-fiscalyear
                 AND accountingdocument = is_doc_map-documentkey(10).


*      DATA(ls_item_dept) = VALUE #( lt_item_sum[ id       = is_doc_map-id
*                                                 item_id  = is_doc_map-item_id ] OPTIONAL ).

      READ TABLE it_doc_account INTO DATA(ls_account) WITH KEY DocType             = 'PP'
                                                               Product             = gs_header-Product
*                                                               department          = ls_item_dept-Department
                                                               ProviderCompanyCode = gs_header-providercompanycode
                                                               TariffType          = '92'
                                                               glaccount1          = ls_journalentryitem-glaccount.
*                                                               GlAccount1          = iv_glaccount1.

      DATA(ls_item_1) = gtd_items_add[ id           = is_doc_map-id
                                       item_id      = is_doc_map-item_id
                                       itembasis_id = is_doc_map-itembasis_id
                                       itemcalc_id  = is_doc_map-itemcalc_id ] .
      lv_item_text = |{ gs_header-providercompanycode }-{ ls_item_1-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
      DATA(lv_amt_doc)    = ls_JournalEntryItem-amountintransactioncurrency.
      DATA(lv_amt_cocode) = ls_JournalEntryItem-amountincompanycodecurrency.

      lv_position_num += 1.
      "92 Posición 1 - Partida
      DATA(ls_glitems) = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
                                       partnercompany      = gs_header-providercompanycode
                                       glaccount           = |{ ls_account-glaccount1 ALPHA = IN }|
                                       documentitemtext    = lv_item_text
                                       assignmentreference = gs_header-productname
                                       material            = gs_header-product
                                       ProfitCenter        = ls_JournalEntryItem-profitcenter
                                       CostCenter          = ls_JournalEntryItem-costcenter
                                       _currencyamount     = VALUE #( ( journalentryitemamount = lv_amt_cocode * -1
                                                                        currency               = ls_JournalEntryItem-companycodecurrency
                                                                        exchangerate           = ls_JournalEntryItem-exchangerate
                                                                        currencyrole           = '10'  )
                                                                      ( journalentryitemamount = lv_amt_doc * -1
                                                                        currency               = ls_JournalEntryItem-globalcurrency
                                                                        exchangerate           = ls_JournalEntryItem-exchangerate
                                                                        currencyrole           = '00'   ) )
                                       ).
      APPEND ls_glitems TO lt_glitems.

      lv_position_num += 1.
      "92 Posición 2 - Contrapartida
      ls_glitems = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
                                       partnercompany      = gs_header-providercompanycode
                                       glaccount           = |{ ls_account-glaccount2 ALPHA = IN }|
                                       documentitemtext    = lv_item_text
                                       assignmentreference = gs_header-productname
                                       material            = gs_header-product
                                       ProfitCenter        = ls_JournalEntryItem-profitcenter
                                       CostCenter          = ls_JournalEntryItem-costcenter
                                       _currencyamount     = VALUE #( ( journalentryitemamount = lv_amt_cocode
                                                                        currency               = ls_JournalEntryItem-companycodecurrency
                                                                        exchangerate           = ls_JournalEntryItem-exchangerate
                                                                        currencyrole           = '10'  )
                                                                      ( journalentryitemamount = lv_amt_doc
                                                                        currency               = ls_JournalEntryItem-globalcurrency
                                                                        exchangerate           = ls_JournalEntryItem-exchangerate
                                                                        currencyrole           = '00'   ) )
                                       ).
      APPEND ls_glitems TO lt_glitems.

    ENDLOOP.
    et_glitems = lt_glitems.
  ENDMETHOD.


  METHOD provision_retencion_uruguay.
    TYPES: lsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           lsty_glitems TYPE LINE OF lsty_post-%param-_glitems,
           lsty_aritems TYPE LINE OF lsty_post-%param-_aritems.

    DATA:
      lt_doc_map_log         TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
      lv_totalpos_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency,
      lv_totalpos_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
      lv_amt_doc             TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_max             TYPE i_journalentryitem-amountinglobalcurrency,
      lv_amt_cocode          TYPE i_journalentryitem-amountincompanycodecurrency,
      lv_perc_no_comp        TYPE zi_intercocompanyrelprodrate-taxcredit,
      lv_doc_key             TYPE zfi_a_intrc_cpd-documentkey,
      lt_glitems             TYPE lsty_post-%param-_glitems,
      lt_aritems             TYPE lsty_post-%param-_aritems,
      ls_tvarvc_data         TYPE gty_tvarvc_data,
      lt_percent_je          TYPE gtty_percent_je,
      lt_percent_his         TYPE gtty_percent_his,
      lt_item_sum            TYPE gtty_item_sum,
      lv_firstday            TYPE datum,
      lv_position_num        TYPE int4,
      lv_item_text           TYPE sgtxt,
      lv_error               TYPE abap_bool,
      lv_tabix               TYPE sy-tabix,
      lv_index_mayor         TYPE sy-tabix,
      lv_account             TYPE hkont,
      lv_customer            TYPE kunnr.

    DATA(lt_doc_map_si) = COND gtty_doc( WHEN it_doc_map_si IS SUPPLIED
                                         THEN it_doc_map_si
                                         ELSE gt_doc_map_si ).

    " 1. Preparación de Fechas
    lv_firstday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01|.
    TRY.
        DATA(lv_lastday) = zcl_interco_utils=>rp_last_day_of_months(
          EXPORTING day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
      CATCH cx_sy_conversion_no_date.
        lv_lastday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod }31|.
    ENDTRY.

    " Solo Uruguay (DRU)
*    CHECK gs_header-providercompanycode = 'DRU'.
    IF lt_doc_map_si IS INITIAL. RETURN. ENDIF.

    " 2. Lectura de Datos y Parámetros
    SELECT je~companycode,
               je~fiscalyear,
               je~accountingdocument,
               je~originalreferencedocument,
               je~postingdate,
               je~documentdate,
               je~exchangerate,
               wt~withholdingtaxcode,
               wt~whldgtaxbaseamtincocodecrcy,
               wt~whldgtaxbaseamtintransaccrcy,
               wt~companycodecurrency,
               wt~documentcurrency,
               ext~whldgtaxrelevantpercent,
               ext~withholdingtaxpercent,
               ext~withholdingtaxpostingrule
          FROM i_journalentry              WITH PRIVILEGED ACCESS AS je
          INNER JOIN i_withholdingtaxitem  WITH PRIVILEGED ACCESS AS wt
            ON  je~companycode        = wt~companycode
            AND je~accountingdocument = wt~accountingdocument
            AND je~fiscalyear         = wt~fiscalyear
          INNER JOIN i_extendedwhldgtaxcode WITH PRIVILEGED ACCESS AS ext
            ON  ext~country            = wt~country
            AND ext~withholdingtaxtype = wt~withholdingtaxtype
            AND ext~withholdingtaxcode = wt~withholdingtaxcode
          FOR ALL ENTRIES IN @lt_doc_map_si
          WHERE je~companycode        = @lt_doc_map_si-companycode
            AND je~fiscalyear         = @lt_doc_map_si-fiscalyear
            AND je~accountingdocument = @lt_doc_map_si-documentkey(10)
          INTO TABLE @DATA(lt_with_item).

    IF lt_with_item IS INITIAL. RETURN. ENDIF.

    me->get_tvarvc( IMPORTING iv_tvarvc_data = ls_tvarvc_data ).
    me->get_percent_of_total( CHANGING ch_item_sum = lt_item_sum ).
    me->get_percent_je( EXPORTING iv_doc_map_si = lt_doc_map_si iv_glaccount_je = ls_tvarvc_data-glaccount_je CHANGING ch_percent_je = lt_percent_je ).
*Ini EXT_OSCUGALD 05.06.2026 - Fix RW033: pasar glaccount_je (provision_retencion_uruguay)
    me->get_percent_his( EXPORTING iv_doc_map_si   = lt_doc_map_si
                                   iv_glaccount_je = ls_tvarvc_data-glaccount_je
                         CHANGING  ch_percent_his  = lt_percent_his ).
*Fin EXT_OSCUGALD 05.06.2026 - Fix RW033

    SELECT providercompanycode,
           recipientcompanycode,
           product,
           taxcredit
      FROM zi_intercocompanyrelprodrate
      FOR ALL ENTRIES IN @gtd_items_add
      WHERE providercompanycode = @gtd_items_add-providercompanycode
        AND recipientcompanycode = @gtd_items_add-recipientcompanycode
        AND product = @gtd_items_add-product
        AND validfrom <= @lv_firstday
        AND validto >= @lv_lastday AND isdeleted = @space
      INTO TABLE @DATA(lt_relprodrate).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

    SELECT companycode,
           internalcode
    FROM zi_intercocompanycode
    FOR ALL ENTRIES IN @lt_doc_map_si
      WHERE companycode = @lt_doc_map_si-companycode
      INTO TABLE @DATA(lt_sitecode).
    IF sy-subrc = 0.
      SORT lt_sitecode BY companycode.
    ENDIF.

    DATA(doc_account_uy) = NEW zcl_interco_doc_glaccount( i_doctype = zcl_interco_doc_glaccount=>co_doc_type-ar
                                                          i_product = gs_header-product
                                                          i_provider_company_code = gs_header-providercompanycode
                                                          i_valid_at = lv_lastday ).
    SORT lt_doc_map_si BY documentkey.
    SORT gtd_items_add BY id item_id itembasis_id itemcalc_id.

    " ── 3. LOOP PRINCIPAL ─────────────────
    LOOP AT lt_doc_map_si INTO DATA(ls_doc_map) GROUP BY ls_doc_map-documentkey.
      TRY.
          DATA(ls_item_1) = gtd_items_add[ id      = ls_doc_map-id
                                      item_id      = ls_doc_map-item_id
                                      itembasis_id = ls_doc_map-itembasis_id
                                      itemcalc_id  = ls_doc_map-itemcalc_id ].

*         "BRF Taxcode
          DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
          DATA tax_code TYPE c LENGTH 2.

          IF ls_tvarvc_data-doctype EQ zcl_interco_doc_glaccount=>co_doc_type-ar.
            brf_helper->get_tax_code(
              EXPORTING
                iv_provider   = gs_header-providercompanycode
                iv_recipient  = ls_item_1-recipientcompanycode
                iv_product    = gs_header-product
              IMPORTING
                ev_taxcode_ar = tax_code
            ).
          ENDIF.

          DATA(ls_relprodrate) = VALUE #( lt_relprodrate[ providercompanycode = ls_item_1-providercompanycode
                                                          recipientcompanycode = ls_item_1-recipientcompanycode
                                                          product = ls_item_1-product ] OPTIONAL ).

          IF ls_relprodrate-taxcredit = 100.
            CONTINUE.
          ENDIF.
          lv_perc_no_comp = 100 - ls_relprodrate-taxcredit.
          lv_perc_no_comp = lv_perc_no_comp / 100.

          " --- LLAMADA AL MÉTODO DE CÁLCULO DE RETENCIÓN (Elimina CI_NESTED 1) ---
          DATA(ls_wht_totals) = me->calculate_uruguay_wht(
            is_doc_map      = ls_doc_map
            it_with_item    = CORRESPONDING #( lt_with_item )
            iv_perc_no_comp = lv_perc_no_comp ).

          IF ls_wht_totals-found = abap_false. CONTINUE. ENDIF.

          DATA(ls_sitecode) = VALUE #( lt_sitecode[ companycode = ls_wht_totals-companycode ] OPTIONAL ).
          IF ls_sitecode-internalcode IS INITIAL.
            lv_doc_key = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
            me->map_error( iv_id = 'ZINT_MSG_INTERCO_CP' iv_number = '27' iv_severity = if_abap_behv_message=>severity-error iv_doc_key = lv_doc_key iv_doc_map = ls_doc_map ).
            lv_error = abap_true. CONTINUE.
          ENDIF.

          DATA(ls_item_dept) = VALUE #( lt_item_sum[ id = ls_doc_map-id  item_id = ls_doc_map-item_id ] OPTIONAL ).

          lv_item_text = |{ gs_header-providercompanycode }-{ ls_item_1-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
          CLEAR: lv_position_num, lt_glitems, lt_aritems, lv_totalpos_amt_doc, lv_totalpos_amt_cocode.

          lv_totalpos_amt_doc    = ls_wht_totals-wth_amt_doc    * -1.
          lv_totalpos_amt_cocode = ls_wht_totals-wth_amt_cocode * -1.

          doc_account_uy->get( EXPORTING i_tarifftype = '93'
                                      i_department = ls_item_dept-department
                            RECEIVING result       = DATA(ls_glaccount_1) ).
          " --- LLAMADA AL MÉTODO DE ÍTEMS GL (Elimina CI_NESTED 2) ---
          " Inicializar rastreo antes del group loop
          CLEAR: lv_amt_max, lv_index_mayor.
          LOOP AT GROUP ls_doc_map INTO DATA(ls_group).
            DATA(lv_cnt_pre) = lines( lt_glitems ).
            me->get_item_sum_loop(
              EXPORTING is_group          = ls_group
                        it_item_sum       = lt_item_sum
                        is_tvarvc_data    = ls_tvarvc_data
*                        is_glaccount_1    = |{ ls_tvarvc_data-glaccount_item_2n ALPHA = IN }|
                        is_glaccount_1    = |{ ls_glaccount_1-glaccount1 ALPHA = IN }|
                        is_sitecode       = ls_sitecode
                        iv_wth_amt_cocode = ls_wht_totals-wth_amt_cocode
                        iv_wth_amt_doc    = ls_wht_totals-wth_amt_doc
                        iv_item_text      = lv_item_text
                        iv_exchangerate   = ls_wht_totals-exchangerate
                        iv_partner_company = ls_item_1-recipientcompanycode
                        it_percent_je     = lt_percent_je
                        it_percent_his    = lt_percent_his
*                        iv_tax_code       = tax_code
                        is_wht_line       = CORRESPONDING #( VALUE #(
                                              lt_with_item[
                                                companycode        = ls_doc_map-companycode
                                                fiscalyear         = ls_doc_map-fiscalyear
                                                accountingdocument = ls_doc_map-documentkey(10)
                                              ] OPTIONAL ) )
              CHANGING  ct_glitems        = lt_glitems
                        cv_position_num   = lv_position_num
                        cv_totalpos_amt_doc    = lv_totalpos_amt_doc
                        cv_totalpos_amt_cocode = lv_totalpos_amt_cocode ).

            " Rastrear mayor entre ítems recién añadidos — DO en lugar de LOOP (ATC-clean)
            DATA(lv_cnt_post) = lines( lt_glitems ).
            DO lv_cnt_post - lv_cnt_pre TIMES.
              READ TABLE lt_glitems INDEX lv_cnt_pre + sy-index
                ASSIGNING FIELD-SYMBOL(<fs_new_gl>).
              IF sy-subrc = 0.
                READ TABLE <fs_new_gl>-_currencyamount
                  WITH KEY currencyrole = '10'
                  ASSIGNING FIELD-SYMBOL(<fs_new_cur>).
                IF sy-subrc = 0 AND abs( <fs_new_cur>-journalentryitemamount ) > abs( lv_amt_max ).
                  lv_amt_max     = <fs_new_cur>-journalentryitemamount.
                  lv_index_mayor = lv_cnt_pre + sy-index.
                ENDIF.
              ENDIF.
            ENDDO.
          ENDLOOP.

          " Redondeo — lv_index_mayor ya calculado durante el loop anterior
          IF ( lv_totalpos_amt_doc < 0 AND lv_totalpos_amt_cocode > 0 ) OR
             ( lv_totalpos_amt_doc > 0 AND lv_totalpos_amt_cocode < 0 ).

            IF lv_index_mayor > 0.
              ASSIGN lt_glitems[ lv_index_mayor ] TO FIELD-SYMBOL(<fs_mayor>).
              READ TABLE <fs_mayor>-_currencyamount
                WITH KEY currencyrole = '10'
                ASSIGNING FIELD-SYMBOL(<fs_mayor_10>).
              IF sy-subrc = 0.
                <fs_mayor_10>-journalentryitemamount -= lv_totalpos_amt_cocode.
              ENDIF.
              READ TABLE <fs_mayor>-_currencyamount
                WITH KEY currencyrole = '00'
                ASSIGNING FIELD-SYMBOL(<fs_mayor_00>).
              IF sy-subrc = 0.
                <fs_mayor_00>-journalentryitemamount -= lv_totalpos_amt_doc.
              ENDIF.
            ENDIF.

          ELSEIF ( lv_totalpos_amt_doc    BETWEEN -1 AND 1 AND lv_totalpos_amt_doc    <> 0 ) OR
                 ( lv_totalpos_amt_cocode BETWEEN -1 AND 1 AND lv_totalpos_amt_cocode <> 0 ).

            lv_account = |{ ls_tvarvc_data-glaccount_redondeo ALPHA = IN }|.
            DATA(lv_cc_red) = ls_tvarvc_data-costcenter_redondeo.
            REPLACE '*' IN lv_cc_red WITH ls_sitecode-internalcode.
            lv_position_num += 1.
            APPEND VALUE #( glaccountlineitem = lv_position_num
                            partnercompany      =  ls_item_1-recipientcompanycode
                            glaccount = lv_account
                            documentitemtext = lv_item_text
                            assignmentreference = gs_header-productname
                            costcenter = lv_cc_red
                            _currencyamount = VALUE #(
                              ( journalentryitemamount = lv_totalpos_amt_cocode * -1
                                currency = ls_wht_totals-currency_co
                                exchangerate = ls_wht_totals-exchangerate
                                currencyrole = '10' )
                              ( journalentryitemamount = lv_totalpos_amt_doc * -1
                                currency = ls_wht_totals-currency_doc
                                exchangerate = ls_wht_totals-exchangerate
                                currencyrole = '00' ) )
                          ) TO lt_glitems.
          ENDIF.

          " AR Item — crédito al cliente IC0116 (recon account 134001 via subledger)
          lv_position_num += 1.
          APPEND VALUE #( glaccountlineitem = lv_position_num
                          customer = |{ ls_item_1-recipientcustomer ALPHA = IN }| "IC0116
                          documentitemtext = lv_item_text
                          assignmentreference = gs_header-productname
                          duecalculationbasedate = ls_wht_totals-postingdate
                          taxcode = tax_code
                          _currencyamount = VALUE #(
                            ( journalentryitemamount = ls_wht_totals-wth_amt_cocode * -1
                              currency = ls_wht_totals-currency_co
                              currencyrole = '10' )
                            ( journalentryitemamount = ls_wht_totals-wth_amt_doc * -1
                              currency = ls_wht_totals-currency_doc
                              currencyrole = '00' ) )
                        ) TO lt_aritems.

          " Mapeo DB y BO Post
          LOOP AT GROUP ls_doc_map INTO DATA(ls_member).
            DATA(ls_item_m) = gtd_items_add[ id           = ls_member-id
                                             item_id      = ls_member-item_id
                                             itembasis_id = ls_member-itembasis_id
                                             itemcalc_id  = ls_member-itemcalc_id ].
            APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_map>).
            <fs_map> = CORRESPONDING #( ls_member ).
            <fs_map>-documentkey = |DUMMY{ ls_member-documentkey }{ ls_item_m-providercompanycode }{ ls_item_m-product }{ ls_item_m-recipientcompanycode }|.
            <fs_map>-parentdocumentkey = ls_member-documentkey(10).
            <fs_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-journalentry_ic.
            <fs_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
          ENDLOOP.

          APPEND INITIAL LINE TO gta_journalentry_post ASSIGNING FIELD-SYMBOL(<je_deep>).
          <je_deep>-%cid = |INT{ sy-tabix }|.
          <je_deep>-%param = VALUE #( companycode = ls_wht_totals-companycode
                                      documentdate = ls_wht_totals-documentdate
                                      postingdate = ls_wht_totals-postingdate
                                      accountingdocumenttype = ls_tvarvc_data-blart
                                      accountingdocumentheadertext = |{ ls_item_1-providercompanycode } { ls_item_1-recipientcompanycode  } { gs_header-productname }|
                                      createdbyuser = cl_abap_context_info=>get_user_technical_name( )
                                      _glitems = lt_glitems
                                      _aritems = lt_aritems ).

          APPEND NEW zcl_proposal_bo_wt_post_par( iv_process = zcl_boproposal_tools=>gc_create_doc
                                                  iv_doc_type = zcl_proposal_bo_abs=>c_document_type-journalentry_ic
                                                  it_doc_map = gt_doc_map_db
                                                  it_je_post = gta_journalentry_post ) TO gtd_list_bo.
          CLEAR: gt_doc_map_db, gta_journalentry_post.

        CATCH cx_sy_itab_line_not_found.
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDTRY.
    ENDLOOP.

    IF lv_error = abap_true.
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.
    IF gtd_list_bo IS NOT INITIAL.
      exe_bo( ).
      save_log( ).
      IF gt_doc_map_db[] IS INITIAL OR
         line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] ) OR
         line_exists( gt_doc_map_db[ status = abap_false ] ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDIF.
    ENDIF.


  ENDMETHOD.


  METHOD calculate_uruguay_wht.
    DATA: lv_ali_grossup TYPE p LENGTH 7 DECIMALS 6,
          lv_perc_wth    TYPE p LENGTH 7 DECIMALS 6,
*          lv_part_to_wth TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent,
          lv_wth_pct     TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
          lv_rel_pct     TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent.
    " Referenciamos los campos de is_doc_map dinámicamente para evitar errores de tipo
    ASSIGN COMPONENT 'COMPANYCODE' OF STRUCTURE is_doc_map TO FIELD-SYMBOL(<lv_bukrs>).
    ASSIGN COMPONENT 'FISCALYEAR'  OF STRUCTURE is_doc_map TO FIELD-SYMBOL(<lv_gjahr>).
    ASSIGN COMPONENT 'DOCUMENTKEY' OF STRUCTURE is_doc_map TO FIELD-SYMBOL(<lv_key>).

    LOOP AT it_with_item ASSIGNING FIELD-SYMBOL(<lfs_wt>)
      WHERE companycode        = <lv_bukrs>
        AND fiscalyear         = <lv_gjahr>
        AND accountingdocument = <lv_key>(10).

      " Ahora el compilador SÍ reconoce los campos
*      DATA(lv_wth_pct) = <lfs_wt>-withholdingtaxpercent   / 100.
*      DATA(lv_rel_pct) = <lfs_wt>-whldgtaxrelevantpercent / 100.
      lv_wth_pct = <lfs_wt>-withholdingtaxpercent   / 100.
      lv_rel_pct = <lfs_wt>-whldgtaxrelevantpercent / 100.

      lv_ali_grossup = lv_wth_pct / ( 1 - lv_wth_pct ).
*      lv_part_to_wth = <lfs_wt>-whldgtaxrelevantpercent.

      IF <lfs_wt>-withholdingtaxpostingrule = '2'.
        lv_perc_wth = lv_ali_grossup.
      ELSE.
        lv_perc_wth = lv_wth_pct.
      ENDIF.

      rs_totals-wth_amt_cocode += <lfs_wt>-whldgtaxbaseamtincocodecrcy  * lv_rel_pct * lv_perc_wth * iv_perc_no_comp.
      rs_totals-wth_amt_doc    += <lfs_wt>-whldgtaxbaseamtintransaccrcy * lv_rel_pct * lv_perc_wth * iv_perc_no_comp.

      rs_totals-companycode  = <lfs_wt>-companycode.
      rs_totals-exchangerate = <lfs_wt>-exchangerate.
      rs_totals-postingdate  = <lfs_wt>-postingdate.
      rs_totals-documentdate = <lfs_wt>-documentdate.
      rs_totals-currency_co  = <lfs_wt>-companycodecurrency.
      rs_totals-currency_doc = <lfs_wt>-documentcurrency.
      rs_totals-found        = abap_true.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_item_sum_loop.
    DATA: lv_cc_code    TYPE zde_cc_code,
          lv_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
          lv_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency.

    " Casting dinámico para los campos de is_group y is_sitecode
    ASSIGN COMPONENT 'ID'           OF STRUCTURE is_group TO FIELD-SYMBOL(<lv_id>).
    ASSIGN COMPONENT 'ITEM_ID'      OF STRUCTURE is_group TO FIELD-SYMBOL(<lv_item_id>).
    ASSIGN COMPONENT 'DOCUMENTKEY'  OF STRUCTURE is_group TO FIELD-SYMBOL(<lv_doc_key>).
    ASSIGN COMPONENT 'COMPANYCODE'  OF STRUCTURE is_group TO FIELD-SYMBOL(<lv_bukrs>).
    ASSIGN COMPONENT 'FISCALYEAR'   OF STRUCTURE is_group TO FIELD-SYMBOL(<lv_gjahr>).
    ASSIGN COMPONENT 'INTERNALCODE' OF STRUCTURE is_sitecode TO FIELD-SYMBOL(<lv_site>).

    LOOP AT it_item_sum INTO DATA(ls_item_sum)
      WHERE id = <lv_id> AND item_id = <lv_item_id>.

      " BRF: Determinar código de Centro de Costo
      DATA(lo_brf_cost) = NEW zcl_interco_brf_wht( ).
      lo_brf_cost->get_cc_code(
        EXPORTING iv_product      = gs_header-product
                  iv_cuenta       = is_glaccount_1
                  iv_cc_origen    = ls_item_sum-costcenterd4
                  iv_departamento = ls_item_sum-department
                  iv_tipo_doc     = is_tvarvc_data-doctype
        RECEIVING rv_cc_code      = lv_cc_code ).

      " Fallbacks del BRF (Lógica original)
      IF lv_cc_code IS INITIAL.
        lo_brf_cost->get_cc_code( EXPORTING iv_product = gs_header-product iv_cc_origen = ls_item_sum-costcenterd4
                                            iv_departamento = ls_item_sum-department iv_tipo_doc = is_tvarvc_data-doctype
                                  RECEIVING rv_cc_code = lv_cc_code ).
      ENDIF.

      " Cálculo de porcentajes e importes
      TRY.
          DATA(ls_percent_je) = it_percent_je[ accountingdocument = <lv_doc_key>(10)
                                               companycode        = <lv_bukrs>
                                               fiscalyear         = <lv_gjahr>
                                               profitcenter       = ls_item_sum-profitcenter ].

          DATA(ls_percent_his) = VALUE #( it_percent_his[ accountingdocument = <lv_doc_key>(10)
                                                          companycode        = <lv_bukrs>
                                                          fiscalyear         = <lv_gjahr>
                                                          profitcenter       = ls_item_sum-profitcenter
                                                          costcenterd4       = ls_item_sum-costcenterd4 ] OPTIONAL ).

          lv_amt_cocode = ( iv_wth_amt_cocode * ls_percent_je-percent ) / 100000 * ( ls_item_sum-percentoftotal / 100000 ).
          lv_amt_doc    = ( iv_wth_amt_doc    * ls_percent_je-percent ) / 100000 * ( ls_item_sum-percentoftotal / 100000 ).

**Ini EXT_OSCUGALD 05.06.2026 - Fix RW033: ignorar percent_his con costcenterd4=0
*          IF ls_percent_his IS NOT INITIAL AND ls_percent_his-costcenterd4 <> 0.
*            lv_amt_cocode = lv_amt_cocode * ( ls_percent_his-percent / 100000 ).
*            lv_amt_doc    = lv_amt_doc    * ( ls_percent_his-percent / 100000 ).
*          ENDIF.
**Fin EXT_OSCUGALD 05.06.2026 - Fix RW033
*   EXT_OSCUGALD 07.06.2026 - Fix RW033: percent_his eliminado con Capa1 activa
*   Con Capa1, percentoftotal suma 100% por PC -> percent_je x percentoftotal = 100%.
*   Aplicar percent_his adicionalmente desbalancea el resultado para docs AI.
*   Para docs IC (percent_his vacio) ya cerraba. Para AI rompia. Se elimina.

        CATCH cx_sy_itab_line_not_found.
          CONTINUE.
      ENDTRY.

      cv_position_num += 1.

      " Llenado de la posición GL
      INSERT VALUE gsty_glitems(
        glaccountlineitem   = cv_position_num
        partnercompany      = iv_partner_company
        glaccount           = |{ is_glaccount_1 ALPHA = IN }|
        documentitemtext    = iv_item_text
        assignmentreference = gs_header-productname
        material            = gs_header-product
        costcenter          = |{ lv_cc_code }{ <lv_site> }{ ls_item_sum-profitcenter ALPHA = OUT }|
*          TaxCode             = iv_tax_code
        _currencyamount     = VALUE #(
          ( journalentryitemamount = lv_amt_cocode
            currency               = is_wht_line-companycodecurrency
            exchangerate           = iv_exchangerate
            currencyrole           = '10' )
          ( journalentryitemamount = lv_amt_doc
            currency               = is_wht_line-documentcurrency
            exchangerate           = iv_exchangerate
            currencyrole           = '00' ) )
      ) INTO TABLE ct_glitems.

      cv_totalpos_amt_doc    += lv_amt_doc.
      cv_totalpos_amt_cocode += lv_amt_cocode.

    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
