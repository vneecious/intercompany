CLASS zcl_proposal_bo_abs DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

*  FINAL
*  CREATE PUBLIC .
  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

    TYPES:
      gtty_c_doc      TYPE TABLE FOR CREATE zi_intercoproposalitemcalc\_itemsdoc .
    TYPES:
*      gtty_c_log      TYPE TABLE FOR CREATE ZI_IntercoProposalItemDoc\_log,
      gty_c_doc       TYPE STRUCTURE FOR CREATE zi_intercoproposalitemcalc\_itemsdoc .
    TYPES:
*      gty_c_log       TYPE STRUCTURE FOR CREATE ZI_IntercoProposalItemDoc\_log,
      gtty_items      TYPE STANDARD TABLE OF zi_intercoproposalitem WITH DEFAULT KEY .
    TYPES:
      gtty_bases      TYPE STANDARD TABLE OF zi_intercoproposalitembasis WITH DEFAULT KEY .
    TYPES:
      gtty_baogl      TYPE STANDARD TABLE OF zc_intecoproposalitembaogl2 WITH DEFAULT KEY .
    TYPES:
      gtty_calc       TYPE STANDARD TABLE OF zi_intercoproposalitemcalc WITH DEFAULT KEY .
    TYPES:
      gtty_doc        TYPE STANDARD TABLE OF zi_intercoproposalitemdoc WITH DEFAULT KEY .
    TYPES:
      gtty_pdoc       TYPE STANDARD TABLE OF zi_intrc_cp_doc WITH DEFAULT KEY .
    TYPES:
      gtsty_bases     TYPE SORTED TABLE OF zi_intercoproposalitembasis WITH UNIQUE KEY primary_key COMPONENTS id item_id itembasis_id .
    TYPES:
      gtsty_baogl     TYPE SORTED TABLE OF zc_intecoproposalitembaogl2 WITH UNIQUE KEY primary_key COMPONENTS id item_id itembasis_id glaccount costcenter .
    TYPES:
      gtsty_calc      TYPE SORTED TABLE OF zi_intercoproposalitemcalc WITH UNIQUE KEY primary_key COMPONENTS id item_id itembasis_id itemcalc_id .
    TYPES:
      gtsty_doc       TYPE SORTED TABLE OF zi_intercoproposalitemdoc WITH UNIQUE KEY primary_key COMPONENTS id item_id itembasis_id itemcalc_id documenttype documentkey .
    TYPES:
      gtsty_pdoc      TYPE SORTED TABLE OF zi_intrc_cp_doc WITH UNIQUE KEY primary_key COMPONENTS id documenttype documentkey .
    TYPES:
      gtty_logs       TYPE STANDARD TABLE OF zfi_a_intrc_cpdl .
    TYPES:
      gtty_parentkey  TYPE STANDARD TABLE OF zfi_a_intrc_cpid-documentkey .
    TYPES:
      gtsty_glaccount TYPE SORTED TABLE OF zst_proposal_reclassif WITH NON-UNIQUE KEY primary_key COMPONENTS companycode product plant valuationclass chartofaccounts transactiontypedetermination valuationareagroup glacctdetndifferentiation .

    TYPES:
      BEGIN OF ty_msg,
        msgid TYPE symsgid,
        msgno TYPE symsgno,
        msgty TYPE symsgty,
        msgv1 TYPE symsgv,
        msgv2 TYPE symsgv,
        msgv3 TYPE symsgv,
        msgv4 TYPE symsgv,
      END OF ty_msg.

*      gtty_purch TYPE TABLE FOR CREATE i_purchaseordertp_2.
    CONSTANTS gc_inflow TYPE c VALUE 'I' ##NO_TEXT.
    CONSTANTS gc_outflow TYPE c VALUE 'O' ##NO_TEXT.
    CONSTANTS:
      BEGIN OF c_proposal_status,
        pending                TYPE zint_dte_cph_status VALUE '',
        verified               TYPE zint_dte_cph_status VALUE 'V',
        calculated             TYPE zint_dte_cph_status VALUE 'C',
        invoicing_started      TYPE zint_dte_cph_status VALUE 'S',
        invoicing_inprogress   TYPE zint_dte_cph_status VALUE 'P',
        invoicing_error        TYPE zint_dte_cph_status VALUE 'E',
        invoiced               TYPE zint_dte_cph_status VALUE 'I',
        reinvoicing_started    TYPE zint_dte_cph_status VALUE 'T',
        reinvoicing_inprogress TYPE zint_dte_cph_status VALUE 'N',
        reinvoicing_error      TYPE zint_dte_cph_status VALUE 'O',
        reinvoiced             TYPE zint_dte_cph_status VALUE 'R',
        anulation_started      TYPE zint_dte_cph_status VALUE 'B',
        anulation_inprogress   TYPE zint_dte_cph_status VALUE 'D',
        anulation_error        TYPE zint_dte_cph_status VALUE 'F',
        anulated               TYPE zint_dte_cph_status VALUE 'A',
        test_invoicing         TYPE zint_dte_cph_status VALUE 'Z',
        test_anulation         TYPE zint_dte_cph_status VALUE 'Y',
        simulation_ok          TYPE zint_dte_cph_status VALUE 'J',
        simulation_error       TYPE zint_dte_cph_status VALUE 'H',
        simulation_started     TYPE zint_dte_cph_status VALUE 'K',
        simulation_inprogress  TYPE zint_dte_cph_status VALUE 'L',
        concluded              TYPE zint_dte_cph_status VALUE 'G',
      END OF c_proposal_status .
    CONSTANTS:
      BEGIN OF c_document_status,
        error           TYPE c VALUE 'E',
        commit          TYPE c VALUE 'C',
        anulated        TYPE c VALUE 'A',
        error_anulated  TYPE c VALUE 'B',
        simulated_ok    TYPE c VALUE 'F',
        simulated_error TYPE c VALUE 'G',
      END OF c_document_status .
    CONSTANTS:
      BEGIN OF c_document_type,
        interdiv                       TYPE zfi_a_intrc_cpd-documenttype VALUE 10,
        salesorder                     TYPE zfi_a_intrc_cpd-documenttype VALUE 20,
        billingdocument                TYPE zfi_a_intrc_cpd-documenttype VALUE 30,
        purchaseorder                  TYPE zfi_a_intrc_cpd-documenttype VALUE 40,
        invoicesupplier                TYPE zfi_a_intrc_cpd-documenttype VALUE 50,
        incomereclassif                TYPE zfi_a_intrc_cpd-documenttype VALUE 60, "Recl_Compras
        expensreclassif                TYPE zfi_a_intrc_cpd-documenttype VALUE 70, "Recl_Gastos
        je_sales                       TYPE zfi_a_intrc_cpd-documenttype VALUE 80, "Doc FI Ventas
        je_purchase                    TYPE zfi_a_intrc_cpd-documenttype VALUE 90, "Doc FI Compras
        anul_interdiv                  TYPE zfi_a_intrc_cpd-documenttype VALUE 100,
        anul_salesorder                TYPE zfi_a_intrc_cpd-documenttype VALUE 110,
        anul_billdoc                   TYPE zfi_a_intrc_cpd-documenttype VALUE 120,
        anul_je_sales                  TYPE zfi_a_intrc_cpd-documenttype VALUE 130, "Doc FI Ventas
        anul_purchorder                TYPE zfi_a_intrc_cpd-documenttype VALUE 140,
        anul_suppinv                   TYPE zfi_a_intrc_cpd-documenttype VALUE 150,
        anul_je_purch                  TYPE zfi_a_intrc_cpd-documenttype VALUE 160, "Doc FI Compras
        anul_incomerec                 TYPE zfi_a_intrc_cpd-documenttype VALUE 170,
        anul_expensrec                 TYPE zfi_a_intrc_cpd-documenttype VALUE 180,
        bd_withholding_post            TYPE zfi_a_intrc_cpd-documenttype VALUE 190, "WT VENTAS
        si_withholding_post            TYPE zfi_a_intrc_cpd-documenttype VALUE 200, "WT COMPRAS
        anul_si_withholding            TYPE zfi_a_intrc_cpd-documenttype VALUE 210, "Anulación WT Compras
        anul_bd_withholding            TYPE zfi_a_intrc_cpd-documenttype VALUE 220, "Anulación WT Ventas
        grossingupreclassif            TYPE zfi_a_intrc_cpd-documenttype VALUE 230, "Reclasificación Grossing Up Prestatario
        anul_grossingup_reclassif      TYPE zfi_a_intrc_cpd-documenttype VALUE 240, "Anulación Reclasificación Grossing Up Prestatario
        journalentry_ic                TYPE zfi_a_intrc_cpd-documenttype VALUE 250, "Asientos contables IC - Uruguay
        anul_journalentry_ic           TYPE zfi_a_intrc_cpd-documenttype VALUE 260, "Anulación Asientos contables IC - Uruguay
        debtprovision                  TYPE zfi_a_intrc_cpd-documenttype VALUE 300, "Previsión de Incobrables PI
        anul_debtprovision             TYPE zfi_a_intrc_cpd-documenttype VALUE 310, "Anulación PI
        " BRAZIL -> BRAZIL ONLY:
        taxbr_sales                    TYPE zfi_a_intrc_cpd-documenttype VALUE 401, " Document for posting local taxes for Sales Brazil -> Brazil
        reverse_taxbr_sales            TYPE zfi_a_intrc_cpd-documenttype VALUE 411, " Reverse document for TAXBR_SALES
        taxbr_sales_contingency        TYPE zfi_a_intrc_cpd-documenttype VALUE 402, " Document for posting local taxes for Sales Brazil -> Brazil (Contingency)
        reverse_taxbr_sales_cont       TYPE zfi_a_intrc_cpd-documenttype VALUE 412, " Reverse document for TAXBR_SALES_CONTINGENCY
        taxbr_sales_reclassif          TYPE zfi_a_intrc_cpd-documenttype VALUE 403, " Reclasification for TAXBR_SALES
        reverse_taxbr_sales_reclassif  TYPE zfi_a_intrc_cpd-documenttype VALUE 413, " Reverse document for TAXBR_SALES_RECLASSIF
        taxbr_sales_cont_reclassif     TYPE zfi_a_intrc_cpd-documenttype VALUE 404, " Reclasification for TAXBR_SALES_CONTINGENCY
        reverse_taxbr_sales_cont_recla TYPE zfi_a_intrc_cpd-documenttype VALUE 414, " Reverse document for TAXBR_SALES_CONT_RECLASSIF
        taxbr_purchases                TYPE zfi_a_intrc_cpd-documenttype VALUE 405, " Document for posting local taxes for Purchases Brazil -> Brazil
        reverse_taxbr_purchases        TYPE zfi_a_intrc_cpd-documenttype VALUE 415, " Reverse document for TAXBR_PURCHASES
        taxbr_purchases_contingency    TYPE zfi_a_intrc_cpd-documenttype VALUE 406, " Document for posting local taxes for Purchases Brazil -> Brazil (Contingency)
        reverse_taxbr_purchases_cont   TYPE zfi_a_intrc_cpd-documenttype VALUE 416, " Reverse document for TAXBR_PURCHASES_CONTINGENCY
        taxbr_purchases_reclassif      TYPE zfi_a_intrc_cpd-documenttype VALUE 407, " Reclasification for TAXBR_PURCHASES
        reverse_taxbr_purchases_reclas TYPE zfi_a_intrc_cpd-documenttype VALUE 417, " Reverse document for TAXBR_PURCHASES_RECLASSIF,
        taxbr_purchases_cont_reclassif TYPE zfi_a_intrc_cpd-documenttype VALUE 408, " Reclasification for TAXBR_PURCHASES_CONTINGENCY
        reverse_taxbr_purchases_cont_r TYPE zfi_a_intrc_cpd-documenttype VALUE 418, " Reverse document for TAXBR_PURCHASES_CONT_RECLASSIF


      END OF c_document_type .
    CONSTANTS:
      BEGIN OF c_document_category,
        interdivision   TYPE zfi_a_intrc_cpd-cat_id VALUE 1,
        order           TYPE zfi_a_intrc_cpd-cat_id VALUE 2,
        invoicing       TYPE zfi_a_intrc_cpd-cat_id VALUE 3,
        reclasification TYPE zfi_a_intrc_cpd-cat_id VALUE 4,
        financial       TYPE zfi_a_intrc_cpd-cat_id VALUE 5,
      END OF c_document_category .
    DATA gs_header TYPE zi_intercoproposal .
    DATA gtd_items_add TYPE ztt_proposalitem_add .
    DATA gtd_bases TYPE gtty_bases .
    DATA gtd_calc TYPE gtty_calc .
    DATA gtd_doc TYPE gtty_doc .
    DATA gtd_anul_doc TYPE gtty_doc .
    DATA gtd_pdoc TYPE gtty_pdoc .
    DATA gts_bases TYPE gtsty_bases .
    DATA gts_calc TYPE gtsty_calc .
    DATA gts_doc TYPE gtsty_doc .
    DATA gts_pdoc TYPE gtsty_pdoc .
    DATA gt_doc_map TYPE gtty_doc .
    DATA gtd_glaccount TYPE ztt_proposal_reclassif .
    DATA gts_glaccount TYPE gtsty_glaccount .
    DATA gtd_logs TYPE gtty_logs .
    DATA gs_items_add TYPE zfi_proposalitem_add .
    DATA gs_bases TYPE zi_intercoproposalitembasis .
    DATA gs_calc TYPE zi_intercoproposalitemcalc .
    DATA:
*          gtc_save_log      TYPE gtty_c_log,
*          gt_c_doc          TYPE gtty_c_doc,
*          gt_c_log          TYPE gtty_c_log,
      gt_intrc_cpid        TYPE STANDARD TABLE OF zfi_a_intrc_cpid .
    DATA:
      gt_intrc_cpd         TYPE STANDARD TABLE OF zfi_a_intrc_cpd .
    DATA:
      gt_intrc_cpdl        TYPE STANDARD TABLE OF zfi_a_intrc_cpdl .
    DATA gv_documentkey TYPE zfi_a_intrc_cpd-documentkey .
    DATA gv_parentdocumentkey TYPE zfi_a_intrc_cpd-parentdocumentkey .
*          gi_count_doc      TYPE i VALUE 0,
*          gi_count_log      TYPE i VALUE 0,
    DATA gv_process TYPE c .
    DATA gtd_baogl TYPE gtty_baogl .
    DATA gts_baogl TYPE gtsty_baogl .
    DATA gtd_baogl_mla TYPE gtty_baogl .
    DATA gts_baogl_mla TYPE gtsty_baogl .

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
        !it_baogl_mla         TYPE gtty_baogl OPTIONAL
        !its_baogl_mla        TYPE gtsty_baogl OPTIONAL.
    METHODS process_bo
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      CHANGING
        !cv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !ct_parentdocument TYPE gtty_parentkey OPTIONAL
      RAISING
        zcx_calc_exit .
    METHODS process_bo_sec
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      CHANGING
        !cv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !ct_parentdocument TYPE gtty_parentkey OPTIONAL
      RAISING
        zcx_calc_exit .
    METHODS process_reverse_sec
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      CHANGING
        !cv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !ct_parentdocument TYPE gtty_parentkey OPTIONAL
      RAISING
        zcx_calc_exit .
  PROTECTED SECTION.

    TYPES:
      ty_message_text TYPE c LENGTH 150 .

    DATA mo_data TYPE REF TO zcl_interco_proposal_data .
    DATA mv_posting_doctype TYPE zint_dte_doctype .
    DATA mv_parent_doctype TYPE zint_dte_doctype.
    DATA mv_reverse_doctype TYPE zint_dte_doctype.
    DATA mv_posting_classname TYPE c LENGTH 40.
    DATA mv_reverse_classname TYPE c LENGTH 40.

    DATA: mt_parallel_processing_list TYPE cl_abap_parallel=>t_in_inst_tab.

    METHODS preparedata .
    METHODS preparedata_reverse .
    METHODS mapping_bo
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      RAISING
        zcx_calc_exit .
    METHODS exe_bo
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL
        !it_map_id_doc     TYPE gtty_doc OPTIONAL
      EXPORTING
        !ev_document       TYPE zfi_a_intrc_cpd-documentkey
        !et_document       TYPE gtty_parentkey .
    METHODS billing_doc
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL
        !is_header         TYPE zi_intercoproposal OPTIONAL
        !it_items          TYPE any OPTIONAL
        !it_bases          TYPE any OPTIONAL
        !it_calc           TYPE any OPTIONAL
        !it_doc            TYPE gtty_doc OPTIONAL
        !its_doc           TYPE gtsty_doc OPTIONAL
      CHANGING
        !ct_doc_map        TYPE gtty_doc OPTIONAL .
    METHODS supplier_inv
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL .
    METHODS mapping_doc_log
      IMPORTING
        !iv_dockey      TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_doctype     TYPE zfi_a_intrc_cpd-documenttype OPTIONAL
        !iv_companycode TYPE zfi_a_intrc_cpd-companycode OPTIONAL
        !iv_fiscalyear  TYPE zfi_a_intrc_cpd-fiscalyear OPTIONAL
        !it_reported    TYPE ANY TABLE OPTIONAL
      CHANGING
        !ct_map_id_doc  TYPE gtty_doc OPTIONAL
        !cv_status      TYPE zfi_a_intrc_cpdl-msgty .
    METHODS mapping_doc
      IMPORTING
        !iv_dockey                 TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_doctype                TYPE zfi_a_intrc_cpd-documenttype OPTIONAL
        !iv_companycode            TYPE zfi_a_intrc_cpd-companycode OPTIONAL
        !iv_fiscalyear             TYPE zfi_a_intrc_cpd-fiscalyear OPTIONAL
        !iv_parentdockey           TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_parentdoctype          TYPE zfi_a_intrc_cpd-documenttype OPTIONAL
        !iv_parentcompanycode      TYPE zfi_a_intrc_cpd-parentcompanycode OPTIONAL
        !iv_parentfiscalyear       TYPE zfi_a_intrc_cpd-parentfiscalyear OPTIONAL
        !iv_status                 TYPE zfi_a_intrc_cpd-status OPTIONAL
        !iv_cat_id                 TYPE zfi_a_intrc_cpd-cat_id OPTIONAL
        !iv_isadjustment           TYPE zfi_a_intrc_cpd-isadjustment OPTIONAL
        !iv_accountingdocumenttype TYPE zfi_a_intrc_cpd-accountingdocumenttype OPTIONAL
        !its_doc                   TYPE gtsty_doc OPTIONAL
        !iv_byuser                 TYPE abp_creation_user OPTIONAL
        !iv_attime                 TYPE abp_creation_tstmpl OPTIONAL
        !iv_isdeleted              TYPE zfi_a_intrc_cpd-isdeleted OPTIONAL
        !iv_process                TYPE c OPTIONAL
      CHANGING
        !ct_map_id_doc             TYPE gtty_doc OPTIONAL .
    METHODS save_document
      IMPORTING
        !iv_dockey        TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_doctype       TYPE zfi_a_intrc_cpd-documenttype OPTIONAL
        !iv_parentdockey  TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_parentdoctype TYPE zfi_a_intrc_cpd-documenttype OPTIONAL
        !iv_status        TYPE zfi_a_intrc_cpd-status OPTIONAL
        !iv_cat_id        TYPE zfi_a_intrc_cpd-cat_id OPTIONAL
        !iv_isadjustment  TYPE zfi_a_intrc_cpd-isadjustment OPTIONAL
        !it_reported      TYPE ANY TABLE OPTIONAL .
    METHODS save_log
      IMPORTING
        !it_logs TYPE gtty_logs OPTIONAL .
*          !it_map_id_doc   TYPE gtty_doc OPTIONAL
    METHODS exe_anulation_bo_sec
      IMPORTING
        !iv_dockey       TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_parentdockey TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
      CHANGING
        !ct_map_id_doc   TYPE gtty_doc OPTIONAL .
    METHODS mapping_bo_sec
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      RAISING
        zcx_calc_exit .
    METHODS mapping_reverse_sec
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !it_parentdocument TYPE gtty_parentkey OPTIONAL
      EXPORTING
        !et_doc_map        TYPE gtty_doc
      RAISING
        zcx_calc_exit .
*          !it_parentdocument TYPE gtty_parentkey OPTIONAL
*          !it_map_id_doc     TYPE gtty_doc OPTIONAL
    METHODS exe_bo_sec
      IMPORTING
        !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
      EXPORTING
        !ev_document       TYPE zfi_a_intrc_cpd-documentkey
        !et_document       TYPE gtty_parentkey
      CHANGING
        !ct_map_id_doc     TYPE gtty_doc OPTIONAL .
    METHODS exe_simulation_anul_bo_sec
      IMPORTING
        !iv_dockey                 TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
        !iv_parentdockey           TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
      CHANGING
        !ct_map_id_doc             TYPE gtty_doc OPTIONAL
        !cv_accountingdocumenttype TYPE zfi_a_intrc_cpd-accountingdocumenttype OPTIONAL
      RETURNING
        VALUE(rv_exist)            TYPE zfi_a_intrc_cpdl-msgty .
    METHODS add_msg_to_log
      IMPORTING
        !iv_current_item TYPE zfi_proposalitem_add
        !iv_dockey       TYPE string
        !iv_doctype      TYPE zfi_a_intrc_cpid-documenttype
        !iv_message_text TYPE ty_message_text OPTIONAL
        !iv_message_type TYPE sy-msgty DEFAULT 'E' .
    METHODS exe_simulation_bo_sec
      IMPORTING
        iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL
      EXPORTING
        ev_document       TYPE zfi_a_intrc_cpd-documentkey
        et_document       TYPE gtty_parentkey
      CHANGING
        ct_map_id_doc     TYPE gtty_doc OPTIONAL .
    METHODS new_message
      IMPORTING
        !id        TYPE symsgid
        !number    TYPE symsgno
        !severity  TYPE if_abap_behv_message=>t_severity
        !v1        TYPE simple OPTIONAL
        !v2        TYPE simple OPTIONAL
        !v3        TYPE simple OPTIONAL
        !v4        TYPE simple OPTIONAL
      RETURNING
        VALUE(obj) TYPE REF TO if_abap_behv_message.

    METHODS new_message_with_text
      IMPORTING
        !severity  TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        !text      TYPE csequence OPTIONAL
      RETURNING
        VALUE(obj) TYPE REF TO if_abap_behv_message .

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 13.10.2026 - C20a: helper de determinación BLART
    METHODS determine_accounting_doctype
      IMPORTING
        i_provider_company_code  TYPE zi_intercodoctypedetermination-providercompanycode
        i_recipient_company_code TYPE zi_intercodoctypedetermination-recipientcompanycode
        i_document_type          TYPE zi_intercodoctypedetermination-doctype
        i_payment_type           TYPE zi_intercodoctypedetermination-paymenttype
        i_amount                 TYPE fis_wsl
        i_fallback_blart         TYPE zi_intercodoctypedetermination-accountingdocumenttype
        i_valid_at               TYPE zi_intercodoctypedetermination-validfrom DEFAULT sy-datum
      RETURNING
        VALUE(result)            TYPE zi_intercodoctypedetermination-accountingdocumenttype.
    " Fin EXT_OSCUGALD 13.10.2026 - C20a
  PRIVATE SECTION.
    DATA: lv_dockey_test TYPE zfi_a_intrc_cpd-documentkey,
          iv_msg         TYPE symsgid. "only uses on unit test

ENDCLASS.



CLASS zcl_proposal_bo_abs IMPLEMENTATION.


  METHOD constructor.
    super->constructor(  ).

    mv_posting_doctype = iv_doctype.
    mo_data = NEW #( iv_proposal_id = is_header-id ).

    DATA: lref_s_data TYPE REF TO data.

    FIELD-SYMBOLS <lt_data> TYPE ANY TABLE.
    TRY.

        IF it_items IS SUPPLIED.
          CREATE DATA lref_s_data LIKE it_items.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_items.
            MOVE-CORRESPONDING <lt_data> TO gtd_items_add.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_bases IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_bases.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_bases.
            MOVE-CORRESPONDING <lt_data> TO gtd_bases.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_bases IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_bases.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_bases.
            MOVE-CORRESPONDING <lt_data> TO gts_bases.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_baogl IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_baogl.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_baogl.
            MOVE-CORRESPONDING <lt_data> TO gtd_baogl.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_baogl IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_baogl.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_baogl.
            MOVE-CORRESPONDING <lt_data> TO gts_baogl.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_baogl_mla IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_baogl_mla.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_baogl_mla.
            MOVE-CORRESPONDING <lt_data> TO gtd_baogl_mla.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_baogl_mla IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_baogl_mla.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_baogl_mla.
            MOVE-CORRESPONDING <lt_data> TO gts_baogl_mla.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_calc IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_calc.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_calc.
            MOVE-CORRESPONDING <lt_data> TO gtd_calc.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_calc IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_calc.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_calc.
            MOVE-CORRESPONDING <lt_data> TO gts_calc.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_doc IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_doc.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_doc.
            MOVE-CORRESPONDING <lt_data> TO gtd_doc.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_anul_doc IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_anul_doc.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_anul_doc.
            MOVE-CORRESPONDING <lt_data> TO gtd_anul_doc.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_doc IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_doc.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_doc.
            MOVE-CORRESPONDING <lt_data> TO gts_doc.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.
        IF it_glaccount IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_glaccount.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_glaccount.
            MOVE-CORRESPONDING <lt_data> TO gtd_glaccount.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF its_glaccount IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE its_glaccount.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = its_glaccount.
            MOVE-CORRESPONDING <lt_data> TO gts_glaccount.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF it_doc_map IS SUPPLIED.
          UNASSIGN <lt_data>.
          CREATE DATA lref_s_data LIKE it_doc_map.
          ASSIGN lref_s_data->* TO <lt_data>.
          IF <lt_data> IS ASSIGNED.
            <lt_data> = it_doc_map.
            MOVE-CORRESPONDING <lt_data> TO gt_doc_map.
          ENDIF.

          FREE: lref_s_data.
        ENDIF.

        IF is_header IS SUPPLIED.
          gs_header = is_header.
        ENDIF.

        IF iv_process IS SUPPLIED.
          gv_process = iv_process.
        ENDIF.

        IF iv_documentkey IS SUPPLIED.
          gv_documentkey = iv_documentkey.
        ENDIF.

        IF iv_parentdocumentkey IS SUPPLIED.
          gv_parentdocumentkey = iv_parentdocumentkey.
        ENDIF.

      CATCH cx_sy_create_data_error
                        cx_sy_assign_cast_illegal_cast
                        cx_sy_assign_cast_unknown_type
                        cx_sy_assign_out_of_range INTO DATA(lref_dynamic_cx).
        "Save log error
        "ID = gs_header-ID
        "MSG = lref_dynamic_cx->get_text( )
        "TYPE =  if_abap_behv_message=>severity-success
    ENDTRY.
  ENDMETHOD.


  METHOD exe_bo.
    " Esta es una implementación genérica que atiende la mayoría de los asientos generados.
    " Casos específicos deben ser implementados directamente en la clase hija.

    DATA lv_debug TYPE abap_boolean.
    DATA lv_status_log TYPE c.
    DATA lt_journalentry TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.


    DATA(lo_parallel_processor) = NEW cl_abap_parallel( ).
    lo_parallel_processor->run_inst(
      EXPORTING
        p_in_tab  = mt_parallel_processing_list
        p_debug   = lv_debug
      IMPORTING
        p_out_tab = DATA(lt_parallel_results)
    ).

    LOOP AT lt_parallel_results REFERENCE INTO DATA(lr_parallel_result).
      DATA lo_bo_parallel TYPE REF TO zcl_proposal_bo_parallel.
      IF lr_parallel_result->inst IS INITIAL.
        lo_bo_parallel = CAST #( mt_parallel_processing_list[ lr_parallel_result->index ] ).
        lt_journalentry = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                         number   = '022'
                                                         severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
            iv_doctype    = mv_posting_doctype
            it_reported   = lt_journalentry
          CHANGING
            ct_map_id_doc = lo_bo_parallel->mt_docmaps
            cv_status     = lv_status_log
        ).

        DATA current_timestamp TYPE abp_creation_tstmpl.
        GET TIME STAMP FIELD current_timestamp.
        mapping_doc( EXPORTING
                               iv_doctype      = mv_posting_doctype
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
                               iv_attime       = current_timestamp
                     CHANGING  ct_map_id_doc   = lo_bo_parallel->mt_docmaps ).

      ELSE.
        lo_bo_parallel ?= lr_parallel_result->inst.
      ENDIF.
      APPEND LINES OF lo_bo_parallel->mt_docmaps TO me->gt_doc_map.
    ENDLOOP.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
*    process_bo( CHANGING cv_parentdocument = lv_dockey_test ).
*    process_bo_sec( CHANGING cv_parentdocument = lv_dockey_test ).
  ENDMETHOD.


  METHOD mapping_bo.

  ENDMETHOD.


  METHOD preparedata.

  ENDMETHOD.


  METHOD process_bo.
    preparedata( ).
    mapping_bo( EXPORTING iv_parentdocument = cv_parentdocument
                          it_parentdocument = ct_parentdocument
                IMPORTING et_doc_map        = et_doc_map ).
*    exe_bo( EXPORTING iv_parentdocument = cv_parentdocument
*                      it_parentdocument = ct_parentdocument
*            IMPORTING ev_document       = cv_parentdocument
*                      et_document       = ct_parentdocument ).
*    save_document( ).
    save_log(  ).
  ENDMETHOD.


  METHOD save_document.


  ENDMETHOD.


  METHOD mapping_doc_log.
    FIELD-SYMBOLS <fs_document> TYPE any.
    FIELD-SYMBOLS <fs_msg>      TYPE REF TO if_abap_behv_message.
    " TODO: variable is assigned but only used in commented-out code (ABAP cleaner)

    DATA ls_map_id_doc TYPE LINE OF gtty_doc.
    DATA ls_intrc_cpdl  TYPE zfi_a_intrc_cpdl.

    ls_map_id_doc = ct_map_id_doc[ 1 ].
    LOOP AT it_reported ASSIGNING <fs_document>.

      ASSIGN COMPONENT '%MSG' OF STRUCTURE <fs_document> TO <fs_msg>.

      ls_intrc_cpdl-id           = ls_map_id_doc-id.
      IF iv_dockey IS INITIAL.
        ls_intrc_cpdl-documentkey = ls_map_id_doc-documentkey.
      ELSE.
        ls_intrc_cpdl-documentkey = iv_dockey.
      ENDIF.
      ls_intrc_cpdl-documenttype = iv_doctype.
      ls_intrc_cpdl-companycode  = iv_companycode.
      ls_intrc_cpdl-fiscalyear   = iv_fiscalyear.
      GET TIME STAMP FIELD ls_intrc_cpdl-tstmpl.
      ls_intrc_cpdl-spras    = sy-langu.
      ls_intrc_cpdl-msgid    = <fs_msg>->if_t100_message~t100key-msgid.
      ls_intrc_cpdl-msgno    = <fs_msg>->if_t100_message~t100key-msgno.
      ls_intrc_cpdl-msgty    = <fs_msg>->if_t100_dyn_msg~msgty.
      ls_intrc_cpdl-msgv1    = <fs_msg>->if_t100_dyn_msg~msgv1.
      ls_intrc_cpdl-msgv2    = <fs_msg>->if_t100_dyn_msg~msgv2.
      ls_intrc_cpdl-msgv3    = <fs_msg>->if_t100_dyn_msg~msgv3.
      ls_intrc_cpdl-msgv4    = <fs_msg>->if_t100_dyn_msg~msgv4.
      ls_intrc_cpdl-message  = <fs_msg>->if_message~get_text( ).
      DATA(ls_id_tmp) = VALUE #( gt_intrc_cpdl[ msgid = ls_intrc_cpdl-msgid
                                                msgno = ls_intrc_cpdl-msgno
                                                msgty = ls_intrc_cpdl-msgty
                                                msgv1 = ls_intrc_cpdl-msgv1
                                                msgv2 = ls_intrc_cpdl-msgv2
                                                msgv3 = ls_intrc_cpdl-msgv3
                                                msgv4 = ls_intrc_cpdl-msgv4 ]-id OPTIONAL ).
      IF ls_id_tmp IS INITIAL.
        APPEND ls_intrc_cpdl TO gt_intrc_cpdl.
      ENDIF.
      IF ls_intrc_cpdl-msgty EQ 'E'.
        cv_status = ls_intrc_cpdl-msgty.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD save_log.
    IF  lines( gt_intrc_cpid ) GT 0.
      MODIFY zfi_a_intrc_cpid FROM TABLE @gt_intrc_cpid.
*      COMMIT WORK.
      FREE: gt_intrc_cpid.
    ENDIF.
    IF  lines( gt_intrc_cpd ) GT 0.
      MODIFY zfi_a_intrc_cpd FROM TABLE @gt_intrc_cpd.
*      COMMIT WORK.
      FREE: gt_intrc_cpd.
    ENDIF.
    IF lines( gt_intrc_cpdl ) GT 0.
      MODIFY zfi_a_intrc_cpdl FROM TABLE @gt_intrc_cpdl.
*      COMMIT WORK.
      FREE: gt_intrc_cpdl.
    ENDIF.
*    ENDIF.
  ENDMETHOD.


  METHOD billing_doc.

  ENDMETHOD.


  METHOD supplier_inv.

  ENDMETHOD.


  METHOD exe_anulation_bo_sec.

  ENDMETHOD.


  METHOD process_bo_sec.
    preparedata( ).
    mapping_bo_sec( EXPORTING iv_parentdocument = cv_parentdocument
                              it_parentdocument = ct_parentdocument
                    IMPORTING et_doc_map        = et_doc_map ).
*    save_document( ).
    save_log(  ).
  ENDMETHOD.


  METHOD exe_bo_sec.

  ENDMETHOD.


  METHOD mapping_bo_sec.

  ENDMETHOD.


  METHOD mapping_reverse_sec.
    DATA: ld_today  TYPE d.
    DATA lt_journal_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse.

    ld_today = cl_abap_context_info=>get_system_date( ).

    SORT gtd_doc BY documentkey.
    DELETE ADJACENT DUPLICATES FROM gtd_doc COMPARING documentkey.


    SELECT i_journalentry~companycode, i_journalentry~fiscalyear, i_journalentry~accountingdocument, postingdate
    FROM i_journalentry
      INNER JOIN @gtd_doc AS documents ON documents~documentkey = i_journalentry~accountingdocument
        AND documents~companycode = i_journalentry~companycode
        AND documents~fiscalyear = i_journalentry~fiscalyear
    INTO TABLE @DATA(lt_posting_date).

    CHECK gtd_doc IS NOT INITIAL.
    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
      DATA(lv_posting_date) = lt_posting_date[ 1 ]-postingdate.

      CLEAR: lt_journal_entry ,gt_doc_map.

      CHECK NOT line_exists( gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ] )
      OR gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ]-documentkey(5) EQ 'DUMMY'.

      APPEND INITIAL LINE TO lt_journal_entry ASSIGNING FIELD-SYMBOL(<jr>).

      <jr>-companycode = <fs_doc>-companycode.
      <jr>-fiscalyear = <fs_doc>-fiscalyear.
      <jr>-accountingdocument = CONV #( <fs_doc>-documentkey ).
      <jr>-%param = VALUE #(
                            postingdate    = lv_posting_date
                            reversalreason = '01'
                            createdbyuser  = cl_abap_context_info=>get_user_technical_name( )
                           ).
      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.
      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-documentkey }|.
      <fs_doc_map>-documenttype = mv_reverse_doctype.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = <fs_doc>-documenttype.

      DATA(lo_parallel_bo) = NEW zcl_proposal_bo_parallel(
                          iv_process = gv_process
                          iv_documenttype = mv_reverse_doctype
                          iv_parent_dockey = <fs_doc>-documentkey
                          iv_parent_doctype = CONV #( <fs_doc>-documenttype )
                          it_doc = gts_doc
                          it_doc_map = gt_doc_map
                          it_reverse = lt_journal_entry ).

      APPEND INITIAL LINE TO mt_parallel_processing_list ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
      <fs_list_bo> = lo_parallel_bo.
      FREE gt_doc_map.
*        exe_anulation_bo_sec(
*        EXPORTING
*          iv_dockey     = <fs_doc>-Documentkey
*          it_map_id_doc = gt_doc_map ).
    ENDLOOP.
    CHECK mt_parallel_processing_list IS NOT INITIAL.
    exe_bo( )."Return the data on me->gt_doc_ma
    et_doc_map = me->gt_doc_map.
    IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

  ENDMETHOD.


  METHOD process_reverse_sec.
    preparedata_reverse(  ).
    mapping_reverse_sec( IMPORTING et_doc_map = et_doc_map ).
    save_log(  ).
  ENDMETHOD.


  METHOD mapping_doc.
*    DATA ls_map_id_doc TYPE LINE OF gtty_doc.
    DATA ls_intrc_cpd  TYPE zfi_a_intrc_cpd.
    DATA ls_intrc_cpid TYPE zfi_a_intrc_cpid.
*    DATA ls_intrc_cpdl  TYPE zfi_a_intrc_cpdl.
*    DATA lv_status TYPE zfi_a_intrc_cpd-status.

    LOOP AT ct_map_id_doc ASSIGNING FIELD-SYMBOL(<fs_map_id_doc>)."INTO ls_map_id_doc.
      "El documento generado solo se debe registrar una sola vez a nivel de cabecera
      CLEAR: ls_intrc_cpd, ls_intrc_cpid.", ls_intrc_cpdl.
      <fs_map_id_doc>-documenttype              = iv_doctype.
      <fs_map_id_doc>-companycode               = iv_companycode.
      <fs_map_id_doc>-fiscalyear                = iv_fiscalyear.
      <fs_map_id_doc>-parentdocumentkey  = iv_parentdockey.
      <fs_map_id_doc>-parentdocumenttype = iv_parentdoctype.
      <fs_map_id_doc>-parentcompanycode  = iv_parentcompanycode.
      <fs_map_id_doc>-parentfiscalyear   = iv_parentfiscalyear.
      <fs_map_id_doc>-cat_id             = iv_cat_id.
      <fs_map_id_doc>-status             = iv_status.
      <fs_map_id_doc>-isadjustment       = iv_isadjustment.
      <fs_map_id_doc>-accountingdocumenttype    = iv_accountingdocumenttype.
      <fs_map_id_doc>-isdeleted          = iv_isdeleted.

      DATA(ls_cpd_id) = VALUE #( gt_intrc_cpd[ id           = <fs_map_id_doc>-id
                                               documentkey  = <fs_map_id_doc>-documentkey
                                               documenttype = <fs_map_id_doc>-documenttype ]-id OPTIONAL ).

      DATA(ls_doc) = VALUE #( its_doc[ id           = <fs_map_id_doc>-id
                                       documentkey  = <fs_map_id_doc>-documentkey
                                       documenttype = <fs_map_id_doc>-documenttype ] OPTIONAL ).
      "Se registra nuevo documento
      IF ls_cpd_id IS INITIAL"Si no existe docmuento durante procesamiento temporal
      AND ls_doc-id IS INITIAL."Si no existe docmuento en bd
        MOVE-CORRESPONDING <fs_map_id_doc> TO ls_intrc_cpd .
        IF iv_dockey IS NOT INITIAL.
          ls_intrc_cpd-documentkey = iv_dockey.
        ENDIF.
        ls_intrc_cpd-createdby          = iv_byuser.
        ls_intrc_cpd-createdat          = iv_attime.
        APPEND ls_intrc_cpd TO gt_intrc_cpd.
        <fs_map_id_doc>-createdby = iv_byuser.
        <fs_map_id_doc>-createdat = iv_attime.
        "Se actualiza la fecha de reprocesamiento del documento
      ELSEIF ls_doc-id IS NOT INITIAL "Si el registro existe en la bd
      AND ls_cpd_id IS INITIAL."Si el registro no existe en la tabla temporal
*        DATA(ls_doc) = its_doc[ id           = <fs_map_id_doc>-id
*                                documentkey  = <fs_map_id_doc>-documentkey
*                                Documenttype = <fs_map_id_doc>-Documenttype ].
        MOVE-CORRESPONDING <fs_map_id_doc> TO ls_intrc_cpd.
        IF iv_dockey IS NOT INITIAL.
          ls_intrc_cpd-documentkey = iv_dockey.
        ENDIF.

        ls_intrc_cpd-createdby    = ls_doc-createdby.
        ls_intrc_cpd-createdat    = ls_doc-createdat.
        ls_intrc_cpd-lastchangeby = iv_byuser.
        ls_intrc_cpd-lastchangeat = iv_attime.
        APPEND ls_intrc_cpd TO gt_intrc_cpd.
        <fs_map_id_doc>-createdby = ls_doc-createdby.
        <fs_map_id_doc>-createdat = ls_doc-createdat.
        <fs_map_id_doc>-lastchangedby = iv_byuser.
        <fs_map_id_doc>-lastchangeat = iv_attime.
      ENDIF.
      "Si la ejecución fue correcta (status = commit) se tiene que marcar como borrado los documentos dummy relacionados
*      <fs_map_id_doc>-Documentkey = ls_intrc_cpd-documentkey.
      IF <fs_map_id_doc>-documentkey(5) = 'DUMMY' AND iv_status EQ me->c_document_status-commit.
        APPEND INITIAL LINE TO gt_intrc_cpd ASSIGNING FIELD-SYMBOL(<fs_cpd_d>).
*        MOVE-CORRESPONDING ls_intrc_cpd TO <fs_cpd_d>.
        MOVE-CORRESPONDING ls_doc TO <fs_cpd_d>.
*        clear: <fs_cpd_d>-fiscalyear, <fs_cpd_d>-companycode.
*        <fs_cpd_d>-documentkey  = <fs_map_id_doc>-Documentkey.
        <fs_cpd_d>-isdeleted    = abap_true.
        <fs_cpd_d>-lastchangeby = cl_abap_context_info=>get_user_technical_name( ).
        GET TIME STAMP FIELD <fs_cpd_d>-lastchangeat.
      ENDIF.
      DATA(ls_cpid_id) = VALUE #( gt_intrc_cpid[ id           = <fs_map_id_doc>-id
                                                 item_id      = <fs_map_id_doc>-item_id
                                                 itembasis_id = <fs_map_id_doc>-itembasis_id
                                                 itemcalc_id  = <fs_map_id_doc>-itemcalc_id
                                                 documentkey  = <fs_map_id_doc>-documentkey
                                                 documenttype = <fs_map_id_doc>-documenttype ]-id OPTIONAL ).

      ls_doc = VALUE #( its_doc[ id           = <fs_map_id_doc>-id
                                 item_id      = <fs_map_id_doc>-item_id
                                 itembasis_id = <fs_map_id_doc>-itembasis_id
                                 itemcalc_id  = <fs_map_id_doc>-itemcalc_id
                                 documentkey  = <fs_map_id_doc>-documentkey
                                 documenttype = <fs_map_id_doc>-documenttype ] OPTIONAL ).
      IF ls_cpid_id IS INITIAL"Si no existe docmuento durante procesamiento temporal
      AND ls_doc-id IS INITIAL."Si no existe docmuento en bd
        "se registra el documento dummy o generado correctamente como log de que posiciones se usaron para ese documento
        MOVE-CORRESPONDING <fs_map_id_doc> TO ls_intrc_cpid.
        IF iv_dockey IS NOT INITIAL.
          ls_intrc_cpid-documentkey = iv_dockey.
        ENDIF.
        ls_intrc_cpid-createdby          = iv_byuser.
        ls_intrc_cpid-createdat          = iv_attime.
        APPEND ls_intrc_cpid TO gt_intrc_cpid.
        <fs_map_id_doc>-createdby = iv_byuser.
        <fs_map_id_doc>-createdat = iv_attime.
      ELSEIF ls_doc-id IS NOT INITIAL "Si existe en la bd
      AND ls_cpid_id IS INITIAL."Si no existe en la tabla temporal
*        ls_doc = its_doc[ id           = <fs_map_id_doc>-id
*                          item_id       = <fs_map_id_doc>-item_id
*                          itembasis_id  = <fs_map_id_doc>-itembasis_id
*                          itemcalc_id   = <fs_map_id_doc>-itemcalc_id
*                          documentkey  = <fs_map_id_doc>-documentkey
*                          Documenttype = <fs_map_id_doc>-Documenttype ].
        MOVE-CORRESPONDING <fs_map_id_doc> TO ls_intrc_cpid.
        IF iv_dockey IS NOT INITIAL.
          ls_intrc_cpid-documentkey = iv_dockey.
        ENDIF.
**        IF <fs_map_id_doc>-LastChangedBy IS INITIAL.
*        ls_doc = its_doc[ 1 ].
**        ENDIF.
        ls_intrc_cpid-createdby = ls_doc-createdby.
        ls_intrc_cpid-createdat = ls_doc-createdat.
        ls_intrc_cpid-lastchangeby = iv_byuser.
        ls_intrc_cpid-lastchangeat = iv_attime.
        <fs_map_id_doc>-createdby = ls_doc-createdby.
        <fs_map_id_doc>-createdat = ls_doc-createdat.
        <fs_map_id_doc>-lastchangedby = iv_byuser.
        <fs_map_id_doc>-lastchangeat = iv_attime.
        APPEND ls_intrc_cpid TO gt_intrc_cpid.
      ENDIF.
      "Si la ejecución fue correcta (status = commit) se tiene que marcar como borrado los documentos dummy relacionados
      IF <fs_map_id_doc>-documentkey(5) = 'DUMMY' AND iv_status EQ me->c_document_status-commit.
*      AND iv_process ne ZCL_BOPROPOSAL_TOOLS=>gc_reverse_doc.
        APPEND INITIAL LINE TO gt_intrc_cpid ASSIGNING FIELD-SYMBOL(<fs_cpid_d>).
*        MOVE-CORRESPONDING ls_intrc_cpid TO <fs_cpid_d>.
        MOVE-CORRESPONDING ls_doc TO <fs_cpid_d>.
*        clear: <fs_cpid_d>-fiscalyear, <fs_cpid_d>-companycode.
*        <fs_cpid_d>-documentkey  = <fs_map_id_doc>-Documentkey.
        <fs_cpid_d>-isdeleted    = abap_true.
        <fs_cpid_d>-lastchangeby = cl_abap_context_info=>get_user_technical_name( ).
        GET TIME STAMP FIELD <fs_cpid_d>-lastchangeat.
      ENDIF.

      IF iv_dockey IS NOT INITIAL.
        <fs_map_id_doc>-documentkey = iv_dockey.
      ENDIF.
      IF iv_parentdockey IS NOT INITIAL.
        <fs_map_id_doc>-parentdocumentkey = iv_parentdockey.
      ENDIF.
*      ls_map_id_doc = <fs_map_id_doc>.
    ENDLOOP.
  ENDMETHOD.


  METHOD exe_simulation_anul_bo_sec.

  ENDMETHOD.


  METHOD preparedata_reverse.
  ENDMETHOD.


  METHOD add_msg_to_log.
    APPEND INITIAL LINE TO gt_intrc_cpdl REFERENCE INTO DATA(message_log).
    message_log->id = iv_current_item-id.
    message_log->documentkey = iv_dockey.
    message_log->documenttype = iv_doctype.
    message_log->message = iv_message_text.
    message_log->msgty = iv_message_type.
    GET TIME STAMP FIELD message_log->tstmpl.
    message_log->spras = sy-langu.
    message_log->message = iv_message_text.
  ENDMETHOD.


  METHOD exe_simulation_bo_sec.

  ENDMETHOD.


  METHOD new_message.
    obj = zcl_behavior_message=>_new_message(
      EXPORTING
        id       = id
        number   = number
        severity = severity
        v1       = v1
        v2       = v2
        v3       = v3
        v4       = v4 ).
  ENDMETHOD.

  METHOD new_message_with_text.
    obj = zcl_behavior_message=>_new_message_with_text(
            severity = severity
            text     = text
          ).
  ENDMETHOD.

  METHOD determine_accounting_doctype.
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 13.10.2026 - C20a: helper de determinación BLART

    result = i_fallback_blart.

    DATA(reader) = NEW zcl_interco_doc_blart(
      i_valid_at              = i_valid_at
      i_doctype               = i_document_type
      i_provider_company_code = i_provider_company_code ).

    DATA(found_blart) = reader->get(
      i_recipientcompanycode = i_recipient_company_code
      i_paymenttype          = i_payment_type
      i_amount               = i_amount ).

    IF found_blart IS NOT INITIAL.
      result = found_blart.
    ENDIF.

    " Fin EXT_OSCUGALD 13.10.2026 - C20a
  ENDMETHOD.
ENDCLASS.
