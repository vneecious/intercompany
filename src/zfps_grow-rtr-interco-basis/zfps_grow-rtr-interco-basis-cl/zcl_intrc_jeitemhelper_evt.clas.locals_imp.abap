*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
class lcl_event_consumption definition inheriting from cl_abap_behavior_event_handler.
  private section.
    methods apply_rules_requested for entity event keys for zr_intercojeitemhelperclass~ApplyRulesRequested.
endclass.


class lcl_event_consumption implementation.

  method apply_rules_requested.

    loop at keys reference into data(key).
      zcl_interco_class_engine_mult=>new( )->for(
        exporting
          i_companycode  = key->CompanyCode
          i_fiscalyear   = key->FiscalYear
          i_fiscalperiod = key->FiscalPeriod
          i_paymenttype  = key->PaymentType
          i_ledger       = key->Ledger
      )->run( ).
    endloop.

  endmethod.

endclass.
