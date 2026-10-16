*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Change ID      : V001                                                *
* Date           : 02.07.2026                                          *
* Description    : Reintegro Gastos - Motor de Calculo IC - F0 Fundaciones y DDIC *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* F2 delta note (06.07.2026): same OT/Solman as F0 -> Change ID V001
* reused per Developer contract's Change ID rule (no new header block).
* This delta closes gap SS A.2 of the F2 blueprint: the calc_strategy
* group is removed (never had a real catalog field behind it, see F0
* drift) and replaced by two groups the Factory/Sources need for their
* first real consumption of this interface (F2 is its first consumer).
*----------------------------------------------------------------------*
"Begin Insert V001 (CC)
INTERFACE zif_reing_ca_c PUBLIC.

  " Line status (zreing_ca_line_status)
  CONSTANTS:
    BEGIN OF line_status,
      calc_proc TYPE zreing_ca_line_status VALUE 'CALC_PROC',
      calc      TYPE zreing_ca_line_status VALUE 'CALC',
      calc_err  TYPE zreing_ca_line_status VALUE 'CALC_ERR',
      sim_proc  TYPE zreing_ca_line_status VALUE 'SIM_PROC',
      sim_ok    TYPE zreing_ca_line_status VALUE 'SIM_OK',
      sim_err   TYPE zreing_ca_line_status VALUE 'SIM_ERR',
      libd      TYPE zreing_ca_line_status VALUE 'LIBD',
      post_proc TYPE zreing_ca_line_status VALUE 'POST_PROC',
      cont      TYPE zreing_ca_line_status VALUE 'CONT',
      post_err  TYPE zreing_ca_line_status VALUE 'POST_ERR',
      anul_proc TYPE zreing_ca_line_status VALUE 'ANUL_PROC',
      " V001 (CC) - #105: terminal state after successful FI reversal.
      anuld     TYPE zreing_ca_line_status VALUE 'ANULD',
      " V001 (CC) - GAP-001 (Delta v2): only reversal retry is allowed.
      anul_err  TYPE zreing_ca_line_status VALUE 'ANUL_ERR',
      "Begin Insert V004 (CC) - F4 (05.08.2026 | EXT_GONZALCA)
      " F4 - Unica constante nueva del grupo: 'PEND' ya existia como valor
      " fijo del dominio ZREING_CA_LINE_STATUS pero no estaba constantizada,
      " y el behavior pool lo usa hoy como literal suelto en >=4 puntos
      " (exportexcel, get_instance_features). Puramente aditivo.
      pend      TYPE zreing_ca_line_status VALUE 'PEND',
      "End Insert V004 (CC) - F4
    END OF line_status.

  " Log action (zreing_ca_action) — orphan_recovery valid because the DE is CHAR 20 (DD-1)
  CONSTANTS:
    BEGIN OF action,
      create          TYPE zreing_ca_action VALUE 'CREATE',
      calc            TYPE zreing_ca_action VALUE 'CALC',
      simulate        TYPE zreing_ca_action VALUE 'SIMULATE',
      release         TYPE zreing_ca_action VALUE 'RELEASE',
      post            TYPE zreing_ca_action VALUE 'POST',
      storno          TYPE zreing_ca_action VALUE 'STORNO',
      reset           TYPE zreing_ca_action VALUE 'RESET',
      warn_ack        TYPE zreing_ca_action VALUE 'WARN_ACK',
      delete          TYPE zreing_ca_action VALUE 'DELETE',
      "Begin Mod V001 (CC)
      "orphan_recovery TYPE zreing_ca_action VALUE 'ORPHAN_RECOVERY',
      " OB-001 (Reviewer Iteration #3, 07.07.2026): the carried-over F0
      " snapshot used in Iteration #1/#2 reproduced the value F0's own
      " review-approval.md documented ('ORPHAN_RECOVERY'), but that is not
      " the value actually active in SAP today — DD07V-DOMVALUE_L is a
      " fixed CHAR10 regardless of the domain's real length, so the value
      " was truncated to 'ORPHAN_REC' when F0 built the fixed value and QA
      " revalidated it live (f0-fundaciones-ddic/qa-approval.md line 15).
      " F2 does not touch this constant group at all — this is a
      " regression fix to the transcription, not a new F2 design decision.
      orphan_recovery TYPE zreing_ca_action VALUE 'ORPHAN_REC',
      "End Mod V001 (CC)
    END OF action.

  " Step category (zreing_ca_step_category)
  CONSTANTS:
    BEGIN OF step_category,
      validate   TYPE zreing_ca_step_category VALUE 'VALIDATE',
      distribute TYPE zreing_ca_step_category VALUE 'DISTRIBUTE',
      gross_up   TYPE zreing_ca_step_category VALUE 'GROSS_UP',
      tax        TYPE zreing_ca_step_category VALUE 'TAX',
      defer      TYPE zreing_ca_step_category VALUE 'DEFER',
      fx         TYPE zreing_ca_step_category VALUE 'FX',
      net        TYPE zreing_ca_step_category VALUE 'NET',
      " Begin Change ID V003 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-06/09
      " -- categoria para las filas generadas por step_delta.
      delta      TYPE zreing_ca_step_category VALUE 'DELTA',
      " End Change ID V003 (03.08.2026 | EXT_GONZALCA)
    END OF step_category.

  " CDS union row type (zreing_ca_row_type) — used in F1
  CONSTANTS:
    BEGIN OF row_type,
      real          TYPE zreing_ca_row_type VALUE 'A',
      cm_pending    TYPE zreing_ca_row_type VALUE 'B1',
      defer_pending TYPE zreing_ca_row_type VALUE 'B2',
    END OF row_type.

  " CONTAB dispatcher mode (zreing_ca_contab_mode)
  CONSTANTS:
    BEGIN OF contab_mode,
      check  TYPE zreing_ca_contab_mode VALUE 'C',
      post   TYPE zreing_ca_contab_mode VALUE 'P',
      storno TYPE zreing_ca_contab_mode VALUE 'S',
    END OF contab_mode.

  "Begin Mod V001 (CC)
  " F2 SS A.2 / F2-DD-4: this group never had a real ZREING_OP_TYPE_C field
  " behind it (CA_CALC_STRATEGY was a drift/never-wired DDIC leftover, see
  " F0 code-summary). The Factory dispatch is resolved instead via
  " cm_loadable/parent_type (SS C.1) — removed, kept here commented for
  " traceability, never re-add.
  "CONSTANTS:
  "  BEGIN OF calc_strategy,
  "    cm    TYPE zreing_ca_calc_strategy VALUE 'CM',
  "    defer TYPE zreing_ca_calc_strategy VALUE 'DEFER',
  "    ant2  TYPE zreing_ca_calc_strategy VALUE 'ANT2',
  "  END OF calc_strategy.
  "End Mod V001 (CC)

  "Begin Insert V001 (CC)
  " F2 SS A.2 / SS C.1: PARENT_TYPE roots the Factory dispatches to for the
  " two non-CM_LOADABLE strategies (D -> parent 'A'; AN2 -> parent 'ANT').
  CONSTANTS:
    BEGIN OF optype_root,
      defer_parent TYPE zreing_op_type VALUE 'A',
      ant2_parent  TYPE zreing_op_type VALUE 'ANT',
    END OF optype_root.

  " F2 SS A.2 / D.2 (N-5): states of ZREING_ME_H_A-me_status eligible for a
  " fresh calculation. Only LIBD today, by user decision — deliberately
  " extensible (add libr here + OR it into get_me_shares' WHERE) without
  " ever needing a literal 'LIBD' scattered across ZCL_REING_CA_SOURCES.
  CONSTANTS:
    BEGIN OF me_eligible_status,
      libd TYPE zreing_me_status VALUE 'LIBD',
    END OF me_eligible_status.
  "End Insert V001 (CC)

  " Insumo Manager (ZREING_CALCUSAGE.insumo_type)
  CONSTANTS:
    BEGIN OF insumo_type,
      me TYPE c LENGTH 2 VALUE 'ME',
      cm TYPE c LENGTH 2 VALUE 'CM',
    END OF insumo_type.

  " TVARVC ids (Orphan Recovery, customizing) — DD-7: RVARI_VNAM is not
  " permitted under Clean Core (ATC ZMELI_CLEAN_CORE_V3); retyped to the
  " new standalone DE ZREING_CA_TVARVC_ID (see ZREING_CA_TVARVC_ID.abap)
  CONSTANTS:
    BEGIN OF tvarvc_id,
      orphan_timeout    TYPE zreing_ca_tvarvc_id VALUE 'ZREING_CA_ORPHAN_TIMEOUT',
      recovery_interval TYPE zreing_ca_tvarvc_id VALUE 'ZREING_CA_RECOVERY_INTERVAL',
      " V001 (CC) - Controlled nonproduction user bypass of the EBA OFF master.
      eba_off_bypass_users TYPE zreing_ca_tvarvc_id VALUE 'ZREING_CA_BR_SW_OFF_BYPASS_USR',
    END OF tvarvc_id.

  "Begin Insert V001 (CC)
  " F5: Application Job Template name(s) -- kept centralized here instead
  " of hardcoded inline in ZCL_REING_CA_ORPHAN_REC (user request, F5,
  " 14.07.2026), same criterion already applied to tvarvc_id above.
  CONSTANTS:
    BEGIN OF apj_job_template,
      orphan_recovery TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZREING_CA_ORPH_RECT',
    END OF apj_job_template.
  "End Insert V001 (CC)

  " V001 (CC) - ISO-01: EBA stays on the existing FX path until cutover.
  CONSTANTS:
    BEGIN OF br_isolation,
      eba_bukrs TYPE bukrs VALUE 'EBA',
      eba_off   TYPE abap_bool VALUE abap_true,
    END OF br_isolation.

  " V001 (CC) - Exact inclusions only; production never reads this list.
  CONSTANTS:
    BEGIN OF br_user_bypass,
      system_ds4 TYPE c LENGTH 3 VALUE 'DS4',
      system_ts4 TYPE c LENGTH 3 VALUE 'TS4',
      selection_type TYPE c LENGTH 1 VALUE 'S',
      include_sign TYPE c LENGTH 1 VALUE 'I',
      equal_option TYPE c LENGTH 2 VALUE 'EQ',
      pattern_chars TYPE string VALUE '*+',
    END OF br_user_bypass.

  " V001 (CC) - Contract modes mirror the verified M/P/H domains.
  CONSTANTS:
    BEGIN OF fx_contract_rate_type,
      manual    TYPE zreing_exrt_type VALUE 'M',
      average   TYPE zreing_exrt_type VALUE 'P',
      inherited TYPE zreing_exrt_type VALUE 'H',
    END OF fx_contract_rate_type.

  " SAP quotation types are distinct from contract modes.
  CONSTANTS:
    BEGIN OF fx_sap_rate_type,
      local_temporary  TYPE kurst_curr VALUE 'M',
      contract_average TYPE kurst_curr VALUE 'ICRG',
    END OF fx_sap_rate_type.

  " Shared monetary representation and canonical-rate constraints.
  CONSTANTS:
    BEGIN OF fx_numeric,
      max_currency_decimals TYPE i VALUE 3,
      sap_amount_decimals   TYPE i VALUE 2,
      decimal_base          TYPE i VALUE 10,
      rate_decimals         TYPE i VALUE 5,
      max_rate              TYPE decfloat34 VALUE '9999.99999',
    END OF fx_numeric.

  CONSTANTS:
    BEGIN OF fx_local_status,
      ok        TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'OK',
      no_rate   TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'NO_RATE',
      precision TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'PRECISION',
      range     TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'RANGE',
      api       TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'API',
      config    TYPE zif_reing_ca_types=>ty_local_fx_status VALUE 'CONFIG',
    END OF fx_local_status.
  CONSTANTS:
    BEGIN OF fx_local_policy,
      temporary_m TYPE zif_reing_ca_types=>ty_local_fx_policy VALUE 'TEMP_M',
      no_op       TYPE zif_reing_ca_types=>ty_local_fx_policy VALUE 'NO_OP',
    END OF fx_local_policy.

  CONSTANTS message_class TYPE symsgid VALUE 'ZREING_CA'.

  " V001 (CC) - Nominal projection and persisted FX-stage protocol.
  CONSTANTS:
    BEGIN OF fx_step,
      number TYPE zreing_ca_step_a-step_num VALUE '05',
      primary_seq TYPE zreing_ca_step_a-seq VALUE '01',
      local_seq TYPE zreing_ca_step_a-seq VALUE '02',
    END OF fx_step,
    BEGIN OF fx_projection_state,
      legacy TYPE zif_reing_ca_types=>ty_trans_state VALUE 'LEGACY',
      available TYPE zif_reing_ca_types=>ty_trans_state VALUE 'AVAILABLE',
      unavailable TYPE zif_reing_ca_types=>ty_trans_state VALUE 'UNAVAILABLE',
    END OF fx_projection_state,
    BEGIN OF fx_projection,
      identity_rate TYPE decfloat34 VALUE '1',
      message_type TYPE symsgty VALUE 'S',
      local_warning TYPE string VALUE 'BR-CA-FX-PRECISION',
    END OF fx_projection,
    BEGIN OF fx_projection_message,
      input TYPE symsgno VALUE '416',
      memory TYPE symsgno VALUE '417',
      currency TYPE symsgno VALUE '418',
      amount TYPE symsgno VALUE '419',
      breakdown TYPE symsgno VALUE '420',
      step_currency TYPE symsgno VALUE '421',
      residual TYPE symsgno VALUE '422',
      local_preview TYPE symsgno VALUE '423',
    END OF fx_projection_message,
    BEGIN OF export_total_kind,
      trans TYPE c LENGTH 1 VALUE 'T',
    END OF export_total_kind.

  " V001 (CC) - bug107 CONTAB: select the cost center per flow step.
  CONSTANTS:
    BEGIN OF kostl_rule,
      formula TYPE zreing_kostl_rule VALUE space,
      contract TYPE zreing_kostl_rule VALUE 'C',
      " V001 (CC) - #121: mapped campaign for the override company.
      campana_map TYPE zreing_kostl_rule VALUE 'Z',
    END OF kostl_rule,
    BEGIN OF kostl_message,
      invalid_company TYPE symsgno VALUE '005',
      missing_contract TYPE symsgno VALUE '006',
      invalid_override TYPE symsgno VALUE '007',
      missing_map TYPE symsgno VALUE '008',
      empty_destination TYPE symsgno VALUE '009',
    END OF kostl_message,
    bukrs_rule_provider TYPE zreing_bukrs_rule VALUE 'P',
    bukrs_rule_override TYPE zreing_bukrs_rule VALUE 'O'.
  " V001 (CC) - #121: shared reclassification selectors, messages and limit.
  CONSTANTS:
    BEGIN OF contab_doc_type,
      reclassification TYPE zreing_doc_type_code VALUE 'ZZZ',
    END OF contab_doc_type,
    BEGIN OF recl_message,
      missing_contract_prctr TYPE symsgno VALUE '012',
      grouped_amount_overflow TYPE symsgno VALUE '013',
      grouped_item_limit TYPE symsgno VALUE '014',
    END OF recl_message,
    recl_max_document_items TYPE i VALUE 999.
ENDINTERFACE.
"End Insert V001 (CC)
